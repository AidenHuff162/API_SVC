module ImportUsersData
  class UploadProfileData
    delegate :add_user_error_to_row, :create_user_error_csv, to: :helper_service

    def initialize(**kwargs)
      @company = kwargs[:company]
      @data =  kwargs[:data] || []
      @current_user = kwargs[:current_user]
      @import_method = kwargs[:import_method]
      @is_tabular = kwargs[:is_tabular]
      @table_name = kwargs[:table_name]
      @date_regex = @company.get_date_regex
      @defected_users = []
      @upload_date = kwargs[:upload_date].to_date.strftime(@company.get_date_format)
      @template = nil
      User.current = @current_user
    end

    def perform
      if @is_tabular
        upload_tabular_information
      else
        upload_users_information
      end
      User.current = nil
    end

    private

    def set_custom_field(user, custom_field, entry)
      entry = Date.strptime(entry, @date_regex) if custom_field.field_type == 'date'
      entry = custom_field.custom_field_options.where(option: entry).pluck(:id) if custom_field.field_type == "multi_select"
      CustomFieldValue.set_custom_field_value(user, custom_field.name, entry)
    end

    def get_custom_field(header, id = nil)
      custom_field = nil
      header = header.strip
      header = header[0..(header.index('"') - 1)] if header.include?('"')
      custom_field = @company.custom_fields.where('name ILIKE ?', header ).first if id.blank?
      custom_field = @company.custom_fields.where('name ILIKE ? AND custom_table_id = ?', header, id).first if id.present?
      custom_field
    end

    def get_sub_custom_field(header, cf)
      sub_custom_field = nil
      header = header[header.index('"') + 1 ..((header.length) - 2)] if header.include?('"')
      sub_custom_field = cf.sub_custom_fields.where('name ILIKE ?', header).first
      sub_custom_field
    end

    def set_sub_custom_field_value(user, sub_custom_field, custom_field_value)
      if sub_custom_field.present? && ['short_text', 'number'].include?( sub_custom_field.field_type)
        user_sub_custom_field_value = sub_custom_field.custom_field_values.find_or_initialize_by(user_id: user.id)
        if sub_custom_field.name == 'State'
          custom_field_value = address_state_value(custom_field_value)
        end
        user_sub_custom_field_value.value_text = custom_field_value
        user_sub_custom_field_value.save!
        set_updated_custom_fields(sub_custom_field, user_sub_custom_field_value.id)
      end
    end

    def set_currency_field(user, custom_field, currency_type, currency_value)
      sub_custom_field = custom_field.sub_custom_fields.find_by('name ILIKE ?', 'Currency Type')
      user_sub_custom_field_value = sub_custom_field.custom_field_values.find_or_initialize_by(user_id: user.id)
      user_sub_custom_field_value.value_text = currency_type
      user_sub_custom_field_value.save!

      sub_custom_field = custom_field.sub_custom_fields.find_by('name ILIKE ?', 'Currency Value')
      user_sub_custom_field_value = sub_custom_field.custom_field_values.find_or_initialize_by(user_id: user.id)
      user_sub_custom_field_value.value_text = currency_value
      user_sub_custom_field_value.save!
    end

    def isProfileField(header)
      header == 'About' || header == 'Linkedin' || header == 'GitHub' || header == 'Twitter' || header == 'Facebook'
    end

    def uploade_image user, url
      begin
        image = UploadedFile::ProfileImage.new
        image.remote_file_url = url
        user.profile_image = image
        user.save!
      rescue Exception => e
      end
    end

    def get_preference_field_id(header, value)
      if header == 'Manager' && value.present?
        manager = @company.users.find_by(email: value.try(:downcase))
        manager.id if manager.present?
      elsif header == 'Location'
        location = @company.locations.where(name: value).first_or_create
        location.id.to_s if location
      elsif header == @company.department
        team = @company.teams.where(name: value).first_or_create
        team.id.to_s if team
      end
    end

    def custom_table_preference_fields
      ['Job Title','Location',@company.department,'Status','Manager']
    end

    def user_info_preference_fields
      ['Paylocity ID']
    end

    def get_prefrence_field(header, custom_table_property = nil)
      field = nil
      if custom_table_property.blank?
       field =  @company.prefrences["default_fields"].select { |field| field if field['name'] == header} rescue nil
      else
        field = @company.prefrences["default_fields"].select { |field| field if field['name'] == header && field['custom_table_property'] == custom_table_property} rescue nil
      end
      field
    end

    def get_prefrence_field_value(field_id, user)
      case field_id
        when 'dpt'
          user.team&.name
        when 'loc'
          user.location&.name
        when 'man'
          user.manager&.full_name
        when 'jt'
          user.title
        when 'st'
          user.state
      end
    end

    def get_user_status(termination_date, last_day_worked, user)
      (termination_date.present? && last_day_worked.present?) || (user.termination_date.present? && Time.now.utc > user&.get_termination_time&.utc) ? 'inactive' : 'active' rescue 'active'
    end

    def address_state_value(state_field_value)
      state = State.find_by(name: state_field_value)
      state&.state_key_required?(@company.integration_type) ? state.key : state_field_value
    end

    def upload_tabular_information
      ctus_uploaded_count = 0
      errors_count = 0
      csv_header = @data[0].keys
      index = 0
      errors_string = ""
      user_count = []
      previous_latest_custom_table_user_snapshot = nil
      @data.each do |row|
        entry = row.dup.to_hash.transform_values! { |a| a&.strip rescue a }
        headers = entry.keys
        user_id = entry['User ID']
        user = fetch_user(user_id, entry['Company Email'])

        custom_tables = @company.enable_custom_table_approval_engine ? @company.custom_tables : @company.custom_tables.where.not(custom_table_property: CustomTable.custom_table_properties[:general])
        custom_table = custom_tables.where('name ILIKE ?', @table_name).last
        user_count.push(user&.id)
        if user && custom_table && (user.onboarding_profile_template.nil? || (user.onboarding_profile_template.present? && user.onboarding_profile_template.profile_template_custom_table_connections.pluck(:custom_table_id).include?(custom_table.id)))
          if custom_table.table_type != 'standard'  && entry['Effective Date'].blank?
            add_user_to_error_list(row, user.try(:id) || user_id, 'Effective date is blanked')
            add_user_error_to_row(row, "Row - #{index} - Effective date is blanked")
            errors_count += 1
            next
          end
          begin
            ctus_uploaded_count += 1
            effective_date = Date.strptime(entry['Effective Date'], @date_regex) rescue nil
            next if custom_table.table_type != 'standard'  && effective_date.blank?

            if custom_table.table_type == 'standard'
              table_user_snapshot = user.custom_table_user_snapshots.create!(custom_table_id: custom_table.id, state: 0)
              previous_latest_custom_table_user_snapshot = CustomTableUserSnapshot.get_latest_standard_snapshot_to_applied(table_user_snapshot.user_id, table_user_snapshot.custom_table_id).where.not(id: table_user_snapshot.id)&.take rescue nil
            else
              params = { custom_table_id: custom_table.id, effective_date: effective_date }
              table_user_snapshot = user.custom_table_user_snapshots.where(params).order(updated_at: :desc).take
              if table_user_snapshot.blank?
                table_user_snapshot = user.custom_table_user_snapshots.create!(params.merge(state: CustomTableUserSnapshot.states[:queue], terminate_job_execution: true)) rescue nil
                previous_latest_custom_table_user_snapshot = CustomTableUserSnapshot.get_latest_snapshot_to_applied(table_user_snapshot.user_id, table_user_snapshot.custom_table_id, table_user_snapshot.effective_date).where.not(id: table_user_snapshot.id)&.take rescue nil
              else
                previous_latest_custom_table_user_snapshot = CustomTableUserSnapshot.get_latest_snapshot_to_applied(table_user_snapshot.user_id, table_user_snapshot.custom_table_id, table_user_snapshot.effective_date)&.take rescue nil
              end
            end
            
            table_user_snapshot.assign_attributes(terminate_callback: true) if headers.include?('Employment Status') && headers.include?('Termination Date') && entry['Termination Date'].present? && Date.strptime(entry['Termination Date'], @date_regex) > Date.today && entry['Effective Date'].present? && Date.strptime(entry['Effective Date'], @date_regex) > Date.today
            table_user_snapshot.assign_attributes(request_state: CustomTableUserSnapshot.request_states[:approved]) if custom_table.is_approval_required.present?
            if custom_table.employment_status?
              entry['Status'] = get_user_status(entry['Termination Date'], entry['Last Day Worked'], user)
              user.terminate_callback = true
              last_day_worked = Date.strptime(entry['Last Day Worked'], @date_regex) rescue nil
              termination_date = Date.strptime(entry['Termination Date'], @date_regex) rescue nil
              termination_type = entry['Termination Type'].try(:downcase) rescue nil
              eligible_for_rehire = entry['Eligible for Rehire'].present? ? entry['Eligible for Rehire'].try(:parameterize).try(:underscore) : nil
              error_message = nil
              save_table_user_snapshot = false
              entry['Effective Date'] = entry['Termination Date'] if entry['Termination Date'].present?
              table_user_snapshot.effective_date = Date.strptime(entry['Effective Date'], @date_regex) rescue nil if entry['Termination Date'].present?
              if user.termination_date.blank? && (termination_date.blank? || last_day_worked.blank?) && entry['Status'].present? && entry['Status'] == 'inactive'
                error_message = "One of the Termination/last day worked dates is missing or both"

              elsif entry['Status'].present? && entry['Status'] == 'active' && (termination_date.present? || last_day_worked.present?)
                error_message = "Termination Data should not have active status"
              
              elsif entry['Status'].present? && entry['Status'] == 'inactive' && termination_date.present? && last_day_worked.present? && (Date.strptime(entry['Last Day Worked'], @date_regex) > Date.strptime(entry['Termination Date'], @date_regex))
                error_message = "User Last day worked should not be greater than termination date"

              elsif user.current_stage == 'departed' && entry['Status'] == 'active' && Date.strptime(entry['Effective Date'], @date_regex) != Date.today
                error_message = "Effective date should be today date for rehire employee"
              
              elsif entry['Status'].present? && entry['Status'] == 'inactive' && termination_date.present? && last_day_worked.present? && (Date.today > Date.strptime(entry['Effective Date'], @date_regex)) && (Date.strptime(entry['Last Day Worked'], @date_regex) <= Date.strptime(entry['Termination Date'], @date_regex))
                # all correct termination data with past effective date
                table_user_snapshot.is_terminated = true
                table_user_snapshot.terminated_data = {last_day_worked: last_day_worked, eligible_for_rehire: eligible_for_rehire, termination_type: termination_type, state: CustomTableUserSnapshot.states[:processed]}
                table_user_snapshot.is_applicable = true
                table_user_snapshot.state = CustomTableUserSnapshot.states[:processed]
                table_user_snapshot.save!
              
              elsif user.last_day_worked.blank? && user.termination_date.blank? && entry['Status'].present? && entry['Status'] == 'inactive' && last_day_worked.present? && termination_date.present? && (Date.strptime(entry['Last Day Worked'], @date_regex) <= Date.strptime(entry['Termination Date'], @date_regex)) && (Date.strptime(entry['Effective Date'], @date_regex) == Date.today)
                # all correct termination data with current effective date
                user.current_stage = 'departed'
                user.state = 'inactive'
                user.termination_date = termination_date
                user.last_day_worked = last_day_worked
                user.termination_type = termination_type
                user.eligible_for_rehire = eligible_for_rehire
                save_table_user_snapshot = true
                table_user_snapshot.is_terminated = true
                table_user_snapshot.terminated_data = {last_day_worked: last_day_worked, eligible_for_rehire: eligible_for_rehire, termination_type: termination_type}
                table_user_snapshot.is_applicable = true
                table_user_snapshot.state = CustomTableUserSnapshot.states[:applied]
                user.save!

              elsif user.last_day_worked.blank? && user.termination_date.blank? && entry['Status'].present? && entry['Status'] == 'inactive' && last_day_worked.present? && termination_date.present? && (Date.strptime(entry['Last Day Worked'], @date_regex) <= Date.strptime(entry['Termination Date'], @date_regex)) && (Date.strptime(entry['Effective Date'], @date_regex) > Date.today)
                # all correct termination data with Future effective date
                save_table_user_snapshot = true
                user.termination_date = termination_date
                user.last_day_worked = last_day_worked
                user.termination_type = termination_type
                user.eligible_for_rehire = eligible_for_rehire
                table_user_snapshot.is_terminated = true
                table_user_snapshot.terminated_data = {last_day_worked: last_day_worked, eligible_for_rehire: eligible_for_rehire, termination_type: termination_type}
                table_user_snapshot.is_applicable = true
                user.save!
              
              elsif user.current_stage == 'departed' && user.state == 'inactive' && user.termination_date && user.last_day_worked  && entry['Status'].present? && entry['Status'] == 'active' && last_day_worked.blank? && termination_date.blank? && (Date.strptime(entry['Effective Date'], @date_regex) == Date.today)
                # rehiring with current effective date
                save_table_user_snapshot = true
                latest_custom_table_user_snapshot = user.custom_table_user_snapshots.find_by(state: 'applied') 
                latest_custom_table_user_snapshot&.update_column(:state, CustomTableUserSnapshot.states[:processed])
                table_user_snapshot.is_applicable = true
                table_user_snapshot.state = CustomTableUserSnapshot.states[:applied]
                user.termination_date = termination_date
                user.last_day_worked = last_day_worked
                user.termination_type = termination_type
                user.is_rehired = true
                user.current_stage = 'invited'
                user.state = 'active'
                user.eligible_for_rehire = eligible_for_rehire
                @template = EmailTemplate.find_by(email_type: 'invitation')
                user_email = user.user_emails.new({
                  subject: @template.subject,
                  cc: @template.cc,
                  bcc: @template.bcc,
                  description: @template.description,
                  email_type: @template.email_type,
                  template_name: @template.name.split('---')[-1],
                  sent_at: nil,
                  email_status: 4,
                  scheduled_from: UserEmail.scheduled_froms[:onboarding],
                  schedule_options: @template.schedule_options,
                  from: @company.email_address,
                  to: [user.email, user.personal_email]
                })
                user.save!
                SendUserEmailsJob.perform_now(user.id, 'onboarding', true, nil , nil, true)
                user.onboarding!
              end
              
              if error_message.present? && (last_day_worked.present? || termination_date.present? || entry['Status'].present? || termination_type.present?)
                add_user_to_error_list(row, user.try(:id) || user_id, error_message)
                add_user_error_to_row(row, "Row - #{index} - #{error_message}")
                errors_count += 1
                table_user_snapshot.delete unless save_table_user_snapshot
                next
              elsif error_message.blank? && save_table_user_snapshot
                table_user_snapshot.save!
              end
            else
              table_user_snapshot.save!
            end
            user.index!

            headers.each do |header|
              next if  header.include?('"') && ['Currency Type', 'Area code', 'Country'].include?(header[header.index('"') + 1 ..((header.length) - 2)]) 
              custom_field = get_custom_field(header, custom_table.id) rescue nil
              prefrence_field = get_prefrence_field(header, custom_table.custom_table_property)[0] rescue nil if custom_table_preference_fields.include?(header)
              if custom_field
                if header == 'Effective Date'
                  if effective_date
                    snapshot = table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id).last
                    if snapshot
                      snapshot.update(custom_field_value: effective_date)
                    else
                      table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_field.id, custom_field_value: effective_date)
                    end
                  end
                elsif custom_field.field_type.eql?('date')
                  custom_field_value = Date.strptime(entry[header], @date_regex) rescue nil
                  snapshot = table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id).last
                  if snapshot
                    snapshot.update(custom_field_value: custom_field_value)
                  else
                    table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_field.id, custom_field_value: custom_field_value)
                  end
                  snapshot = nil
                elsif custom_field.field_type == 'currency' && entry[header].present?
                  currency_value = ""
                  currency_type = entry[custom_field.name + '"Currency Type"'] rescue 'USD'
                  currency = entry[header].gsub(/[\s,]/ ,"").to_f if entry[header].present?
                  currency_value = "#{currency_type}|#{currency}"
                  snapshot = table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id).last
                  if snapshot
                    snapshot.update(custom_field_value: currency_value)
                  else
                    table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_field.id, custom_field_value: currency_value)
                  end
                  snapshot = nil
                elsif custom_field.field_type == 'phone' && entry[header].present?
                  phone_value = ""
                  country = entry[custom_field.name + '"Country"']
                  area = entry[custom_field.name + '"Area code"']
                  phone = entry[custom_field.name + '"Phone"']
                  phone_value = "#{country}|#{area}|#{phone}"
                  snapshot = table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id).last
                  if snapshot
                    snapshot.update(custom_field_value: phone_value)
                  else
                    table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_field.id, custom_field_value: phone_value)
                  end
                  snapshot = nil
                else
                  custom_field_value = ""
                  if custom_field.coworker?
                    coworker_id = user.company.users.find_by(id: entry[header]).try(:id)
                    coworker_id = user.company.users.find_by(guid: entry[header]).try(:id) if !coworker_id
                    coworker_id = user.company.users.find_by(email: entry[header]).try(:id) if !coworker_id
                    coworker_id = user.company.users.find_by(personal_email: entry[header]).try(:id) if !coworker_id
                    custom_field_value = coworker_id.to_s
                  elsif custom_field.custom_field_options.count > 0
                    custom_field_value = CustomFieldOption.get_custom_field_option(custom_field, entry[header]).try(:id).to_s
                  else
                    custom_field_value = entry[header]
                  end
                  snapshot = table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id).last

                  if snapshot
                    snapshot.update(custom_field_value: custom_field_value)
                  else
                    table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_field.id, custom_field_value: custom_field_value)
                  end
                  snapshot = nil
                end

              elsif prefrence_field
                custom_field_value = ""
                custom_field_value = entry[header] if header == 'Job Title'
                custom_field_value = entry[header].try(:downcase) if header == 'Status'
                custom_field_value = get_preference_field_id(header, entry[header]) if entry[header].present? && (header == 'Location' || header == @company.department || header == 'Manager')
                snapshot = table_user_snapshot.custom_snapshots.where(preference_field_id: prefrence_field['id']).last
                
                if custom_field_value.blank? &&
                   prefrence_field['id'].downcase.eql?('st') &&
                   (table_user_snapshot.is_terminated || table_user_snapshot.terminated_data.present?)
                  custom_field_value = 'inactive'
                end

                if snapshot
                  snapshot.update(custom_field_value: custom_field_value)
                else
                  table_user_snapshot.custom_snapshots.create!(preference_field_id: prefrence_field['id'], custom_field_value: custom_field_value)
                end
                snapshot = nil
              end
            end

            table_user_snapshot.edited_by_id = @current_user.id
            table_user_snapshot.created_through_flatfile = true
            table_user_snapshot.terminate_job_execution = true

            current_custom_snapshots = table_user_snapshot.try(:custom_snapshots)
            if current_custom_snapshots.present?
              table_fields_count = custom_table.try(:custom_fields).present? ? custom_table.custom_fields.count : 0
              pref_fields = []
              if custom_table.custom_table_property.downcase.eql?('role_information')
                dpt_default_field = @company.prefrences['default_fields'].select { |pref_field| (pref_field['id'] == 'dpt' && pref_field['profile_setup'] == 'custom_table' && pref_field['custom_table_property'] == 'role_information') } rescue nil
                loc_default_field = @company.prefrences['default_fields'].select { |pref_field| (pref_field['id'] == 'loc' && pref_field['profile_setup'] == 'custom_table' && pref_field['custom_table_property'] == 'role_information') } rescue nil
                man_default_field = @company.prefrences['default_fields'].select { |pref_field| (pref_field['id'] == 'man' && pref_field['profile_setup'] == 'custom_table' && pref_field['custom_table_property'] == 'role_information') } rescue nil
                jt_default_field = @company.prefrences['default_fields'].select { |pref_field| (pref_field['id'] == 'jt' && pref_field['profile_setup'] == 'custom_table' && pref_field['custom_table_property'] == 'role_information') } rescue nil
                
                if dpt_default_field.present?
                  table_fields_count += 1
                  pref_fields.push('dpt')
                end

                if loc_default_field.present?
                  table_fields_count += 1
                  pref_fields.push('loc')
                end

                if man_default_field.present?
                  table_fields_count += 1
                  pref_fields.push('man')
                end

                if jt_default_field.present?
                  table_fields_count += 1
                  pref_fields.push('jt')
                end
              elsif custom_table.custom_table_property.downcase.eql?('employment_status')
                st_default_field = @company.prefrences['default_fields'].select { |pref_field| (pref_field['id'] == 'st' && pref_field['profile_setup'] == 'custom_table' && pref_field['custom_table_property'] == 'employment_status') } rescue nil

                if st_default_field.present?
                  table_fields_count += 1
                  pref_fields.push('st')
                end
              end

              if table_fields_count > current_custom_snapshots.count
                # Fixing impacted custom fields
                custom_table.try(:custom_fields).try(:each) do |cfs|
                  next if current_custom_snapshots.where(custom_field_id: cfs.id).present?

                  previous_custom_snapshot = previous_latest_custom_table_user_snapshot.try(:custom_snapshots).where(custom_field_id: cfs.id).take rescue nil
                  new_custom_snapshot_value = if previous_custom_snapshot.present?
                                                 previous_custom_snapshot.custom_field_value
                                              else
                                                 user.get_custom_field_value_text(cfs.name, false, nil, cfs)
                                              end
                  current_custom_snapshots.create!(custom_field_id: cfs.id, custom_field_value: new_custom_snapshot_value)
                end

                # Fixing impacted preference fields
                pref_fields.try(:each) do |pfs|
                  next if current_custom_snapshots.where(preference_field_id: pfs).present?

                  previous_custom_snapshot = previous_latest_custom_table_user_snapshot.try(:custom_snapshots).where(preference_field_id: pfs).take rescue nil
                  if pfs.downcase.eql?('st') && (table_user_snapshot.is_terminated || table_user_snapshot.terminated_data.present?)
                    #Staying employment status inactive for offboarded user
                    new_custom_snapshot_value = 'inactive'
                  else
                    new_custom_snapshot_value = if previous_custom_snapshot&.custom_field_value.present?
                                                   previous_custom_snapshot.custom_field_value
                                                else
                                                  get_prefrence_field_value(pfs, user)
                                                end
                  end
                  current_custom_snapshots.create!(preference_field_id: pfs, custom_field_value: new_custom_snapshot_value)
                end
              elsif table_fields_count < current_custom_snapshots.count   
                custom_table.try(:custom_fields).try(:each) do |cfs|
                  custom_field_snapshots = current_custom_snapshots.where(custom_field_id: cfs.id)
                  if custom_field_snapshots.count > 1
                    cfs_id = custom_field_snapshots.order(updated_at: :desc).take.try(:id)
                    custom_field_snapshots.where.not(id: cfs_id).destroy_all
                  end
                end
                pref_fields.try(:each) do |pfs|
                  pref_field_snapshots = current_custom_snapshots.where(preference_field_id: pfs)
                  if pref_field_snapshots.count > 1
                    cfs_id = pref_field_snapshots.order(updated_at: :desc).take.try(:id)
                    pref_field_snapshots.where.not(id: cfs_id).destroy_all
                  end
                end
              end
            end
            table_user_snapshot.save!
            ::CustomTables::ManageCsvCustomSnapshotsJob.perform_later(table_user_snapshot) if table_user_snapshot.reload.applied?
          rescue StandardError => e
            add_user_to_error_list(row, user.try(:id) || user_id, e.message)
            add_user_error_to_row(row, "Row - #{index} - #{e.message}")
            table_user_snapshot.destroy! if table_user_snapshot.custom_snapshots.count == 0
            errors_string += "<br> Row - "+ errors_count.to_s+" - Error in Uploading Tabular Data : " + e.to_s
            errors_count += 1
            next
          end
        else
          add_user_to_error_list(row, user.try(:id) || user_id, 'User or another important information has been missed')
          add_user_error_to_row(row, "Row - #{index} - User or another important information has been missed")
          errors_count += 1
        end

      end
      index = 0
      response  = "Table Snapshots Uploaded : " + ctus_uploaded_count.to_s
      response += "<br><b>Errors occurred During Upload : </b><br>" + errors_string if errors_count > 0

      file = create_user_error_csv(@data, { header: csv_header, section_name: 'existing_profile', company: @company }) if errors_count > 0 && @data
      UserMailer.upload_user_feedback_email(@company, @current_user.email, @current_user.first_name, @defected_users,
                                            user_count.uniq.count, @upload_date, file, 'existing_profile').deliver_now!
      File.delete(file) if file
    end

    def upload_users_information
      company = @company
      users_created_count = 0
      users_updated_count = 0
      errors_count = 0
      user_count = []
      fields_updated_count = 0
      errors_string = ""
      custom_tables = company.custom_tables
      section_name = ''
      csv_header = @data[0].keys
      index = 0

      old_custom_field_data = []
      custom_fields = company.custom_fields.pluck(:name)
      sub_custom_fields = []

      company.custom_fields.find_each do |cf|
        if CustomField.typehHasSubFields(cf.field_type)
          sub_custom_fields.push cf.sub_custom_fields.pluck(:name)
        end
      end
      @data.each do |row|
        index += 1
        entry = row.dup.to_hash.transform_values! { |a| a&.strip rescue a }
        entry.delete_if { |_k, v| v == '' }

        headers = entry.keys
        team = company.teams.where(name: entry[company.department]).first_or_create if entry[company.department].present?
        location = company.locations.where(name: entry['Location']).first_or_create if entry['Location'].present?

        user_id = entry.delete('User ID')
        uid = nil
        user = nil
        start_date = Date.strptime(entry['Start Date'], @date_regex)  rescue Date.yesterday
        preferred_name = entry['Preferred Name'] rescue nil
        first_name = entry['First Name'] rescue nil
        last_name = entry['Last Name'] rescue nil
        title = entry['Job Title'] rescue nil
        email = entry['Company Email'].try(:downcase)
        personal_email = entry['Personal Email'].try(:downcase)
        provider = email ? 'email' : 'personal_email'

        termination_date = Date.strptime(entry['Termination Date'], @date_regex) rescue nil
        termination_type = entry['Termination Type'].try(:downcase) rescue nil
        last_day_worked = entry['Last Day Worked'].present? ?
                            Date.strptime(entry['Last Day Worked'], @date_regex) : termination_date
        eligible_for_rehire = entry['Eligible for Rehire'].present? ?
                                entry['Eligible for Rehire'].try(:downcase) : User.eligible_for_rehires[:no]
        stage =  User.current_stages[entry['Stage'].parameterize.underscore] if entry['Stage'].present?
        integration_custom_fields = {}
        user_updated_changes = []

        temp_user = fetch_user(user_id, email)
        user_count.push(temp_user&.id)
        temp_profile = temp_user&.profile
        temp_profile.id = temp_profile.user_id if temp_profile
        state = get_user_status(entry['Termination Date'], entry['Last Day Worked'], user).try(:downcase)

        if @import_method == 'update_user' 
          begin
            section_name = 'existing_profile'
            user = temp_user.reload
            
            if entry['Start Date'].present? && start_date != user.start_date
              user_updated_changes.push('start_date')
              user.start_date = start_date
            end

            if personal_email.present?
              user_updated_changes.push('personal_email') if personal_email != user.personal_email
              user.personal_email = personal_email
            end

            if email.present?
              user_updated_changes.push('email') if email != user.email
              user.email =  email
            end

            if preferred_name.present?
              user_updated_changes.push('preferred_name') if preferred_name != user.preferred_name
              user.preferred_name = preferred_name
            end

            if first_name.present?
              user_updated_changes.push('first_name') if first_name != user.first_name
              user.first_name = first_name
            end

            if last_name.present?
              user_updated_changes.push('last_name') if last_name != user.last_name
              user.last_name = last_name
            end

            if company.is_using_custom_table.blank? or custom_tables.having_property(CustomTable.custom_table_properties[:role_information]).empty?
              if entry[company.department].present? && team.present? && team.id != user.team_id
                user_updated_changes.push('team_id')
                user.team_id = team.id
              end

              if entry['Location'].present? && location.present? && location.id != user.location_id
                user_updated_changes.push('location_id')
                user.location_id = location.id
              end

              if entry['Job Title'].present? && title.present? && title != user.title
                user_updated_changes.push('title')
                user.title = title
              end

              if entry['Manager'].present?
                manager = company.users.find_by(email: entry['Manager']) || company.users.find_by(personal_email: entry['Manager'])
                if manager.present?
                  user_updated_changes.push('manager_id')
                  user.manager = manager
                end
              end
              if (headers.include?('Termination Date') && termination_date.present? &&
                  termination_date != user.termination_date)
                user.termination_date = termination_date 
              end

              if (headers.include?('Last Day Worked') && last_day_worked.present? &&
                  last_day_worked != user.last_day_worked)
                user.last_day_worked = last_day_worked
              end

              if (headers.include?('Termination Type') && termination_type.present? &&
                  termination_type != user.termination_type)
                user.termination_type = termination_type
              end

              if (headers.include?('Eligible for Rehire') && eligible_for_rehire.present? &&
                  eligible_for_rehire != user.eligible_for_rehire)
                user.eligible_for_rehire = eligible_for_rehire
              end
            end

            if(state.present? && user.state != state) && \
              (!company.is_using_custom_table or custom_tables.having_property(CustomTable.custom_table_properties[:employment_status]).empty?)
              user_updated_changes.push('state')
              user.state = state
            end

            users_updated_count += 1
            user.save!
            ::IntegrationsService::UpdateIntegrationThroughFlatfile.new(user, user_updated_changes.uniq).perform if user_updated_changes.present?
          rescue StandardError => e
            add_user_to_error_list(row, (user.try(:id) || user_id), "Row - "+index.to_s+" - "+e.message.split(',')[0])
            add_user_error_to_row(row, "Row - #{index} - #{e.message.split(',')[0]}")
            errors_count += 1
            errors_string += "<br> Row - "+index.to_s+" - Error in Updating User : " + e.to_s
            next
          end
        elsif @import_method == 'create_user'
          section_name = 'new_profile'
          begin
            user = company.users.create!(
              first_name: entry['First Name'].gsub(/\b\w/, &:capitalize),
              last_name: entry['Last Name'].gsub(/\b\w/, &:capitalize),
              preferred_name: preferred_name,
              title: title,
              team: team,
              location: location,
              email: email,
              personal_email: personal_email,
              provider: provider,
              role: :employee,
              current_stage: 11,
              password: ENV['USER_PASSWORD'],
              state: 'active',
              start_date: start_date,
              # termination_date: termination_date,
              # termination_type: termination_type,
              # last_day_worked: last_day_worked,
              # eligible_for_rehire: eligible_for_rehire,
              is_form_completed_by_manager: "completed"
            )
            user_count.push(user.id)
            user.setup_calendar_event(user, 'start_date', user.company)
            user.setup_calendar_event(user, 'anniversary', user.company)
            users_created_count += 1
          rescue StandardError => e
            add_user_error_to_row(row, "Row - #{index} - #{e.message.split(',')[0]}")
            add_user_to_error_list(row, user.try(:id), "Row - "+index.to_s+" - "+e.message.split(',')[0])
            errors_count += 1
            errors_string += "<br> Row - "+index.to_s+" - Error in creating User : " + e.to_s
            next
          end
        end

        user&.create_profile! if user&.profile.blank?

        # if entry['Termination Date'].present?
        #   user.update_column('current_stage', 6)
        # end
        @changed_custom_value_ids = Set.new
        @updated_custom_fields = Set.new
        headers.each do |header|
          custom_field = get_custom_field(header) rescue nil
          sub_custom_field = get_sub_custom_field(header, custom_field) rescue nil
          preference_field = get_prefrence_field(header)[0] rescue nil if user_info_preference_fields.include?(header)
          begin
            if custom_field && !entry[header].nil? && entry[header] != '' && sub_custom_field.nil?
              old_value = user.get_custom_field_value_text(custom_field&.name)
              set_custom_field(user, custom_field, entry[header])
              custom_values_changed(user, old_value, old_custom_field_data, custom_field)
            elsif sub_custom_field && entry[header].present? && custom_field.present?
              custom_field_name = CustomField.find(sub_custom_field.custom_field_id)
              old_value = user.get_custom_field_value_text(custom_field_name&.name)
              set_sub_custom_field_value(user, sub_custom_field, entry[header])
              custom_values_changed(user, old_value, old_custom_field_data, custom_field_name, true)                          
            elsif isProfileField(header)
              user_updated_changes.push(header== 'About' ? 'about_you' : header.parameterize.underscore)
              user.profile.update_column((header== 'About' ? 'about_you' : header.parameterize.underscore), entry[header])
              user.profile.flush_cache
            elsif preference_field && entry[header].present?
              user.update_column('paylocity_id', entry[header]) if header == 'Paylocity ID'
            elsif ['Manager', 'Buddy'].include?(header) 
              manager = company.users.find_by(email: entry[header])
              manager = company.users.find_by(personal_email: entry[header]) if manager.nil?
              user.update("#{header.parameterize}": manager)
            end
            fields_updated_count += 1
            integration_custom_fields[custom_field.id] =  custom_field.name if custom_field.present?
          rescue StandardError => e
            errors_count += 1
            errors_string += "<br> Row - "+index.to_s+" - Error in Setting Custom Fields : " + e.to_s
            next
          end
        end
        create_address_field_histories(user)
        user.index!

        ::IntegrationsService::UpdateIntegrationThroughFlatfile.new(user, [], integration_custom_fields).perform if @import_method == 'update_user' && integration_custom_fields.present?
        begin
          WebhookEvents::ManageWebhookPayloadJob.perform_async(company.id, {default_data_change: user_updated_changes, user: user.id, temp_user: temp_user.attributes, webhook_custom_field_data: old_custom_field_data, temp_profile: temp_profile.attributes})
        rescue Exception => e
          puts e.message
        end
        old_custom_field_data.clear
        index = 0
      rescue Exception => e
        add_user_error_to_row(row, "Row - #{index} - #{e.message}")
        add_user_to_error_list(row, user.try(:id), e.message)
        errors_count += 1
        errors_string += "<br><br> <b>General Error :</b> <br> #{e.to_s}"
      end
      response  = "Users Created : #{users_created_count}"
      response += "<br>Users Updated : #{users_updated_count}"
      response += "<br>Custom Fields Updated : #{fields_updated_count}"
      response += "<br>Total Errors occurred : #{errors_count}"
      response += "<br><b>Errors occurred During Upload : </b><br>#{errors_string}" if errors_count.positive?

      file = create_user_error_csv(@data, { header: csv_header, section_name: section_name, company: @company }) if errors_count > 0 && @data
      UserMailer.upload_user_feedback_email(company, @current_user.email, @current_user.first_name, @defected_users,
                                            user_count.compact.uniq.count, @upload_date, file, section_name).deliver_now!
      File.delete(file) if file
    end

    def fetch_user(user_id, company_email)
      @company.users.where("id = ? OR email = ?", user_id&.to_i, company_email.try(:downcase)).take
    end

    def custom_values_changed(user, old_value, old_custom_field_data, field, is_sub_custom=false)
      new_value = user.get_custom_field_value_text(field&.name)
      old_custom_field_data.push({name: field&.name, old_value: old_value}) if ((old_value != new_value) && (!is_sub_custom || (is_sub_custom && old_custom_field_data.find_all { |old_field| old_field[:name] == field&.name }.empty?)))
    end

    def add_user_to_error_list entry, user_id, error_message
      name = "#{entry['First Name']} #{entry['Last Name']}" if entry['First Name'] && entry['Last Name']
      name = "#{entry['First Name']} #{entry['Last Name']}" if entry['Preferred Name'] && entry['Last Name'] && entry['First Name'].nil?
      name = "#{entry['Company Email']}" if name.blank?
      name = user_id.to_s if name.blank?
      @defected_users << {name: name, link: user_id.present? ? "https://#{@company.domain}/#/profile/#{user_id}" : '', error: error_message}
    end

    def set_updated_custom_fields(sub_custom_field, user_sub_custom_field_id)
      return unless sub_custom_field.custom_field.field_type.eql?('address')

      @changed_custom_value_ids << user_sub_custom_field_id
      @updated_custom_fields << sub_custom_field.custom_field
    end

    def create_address_field_histories(user)
      updated_custom_values = CustomFieldValue.includes(sub_custom_field: :custom_field)
                                              .where(id: @changed_custom_value_ids.to_a)
      @updated_custom_fields.each do |custom_field|
        changed_custom_field_values = updated_custom_values.where(custom_fields: { id: custom_field.id })
                                                            .order('sub_custom_fields.id asc')
        changed_fields = SubCustomField.where(id: changed_custom_field_values.collect(&:sub_custom_field_id)).map(&:name)
        changed_values = changed_custom_field_values.collect(&:value_text)
        changed_fields_and_values = changed_fields.zip(changed_values).to_h        
        custom_field.track_changed_fields(custom_field, user, changed_fields_and_values, false)
      end
    end

    def helper_service
      ImportUsersData::Helper.new
    end
  end
end
