class UploadUserInformationService
  def initialize company, csv, email, demo, file_url=nil
    @company = company
    @csv = csv
    @email = email
    @demo = demo
    @file_url= file_url
    @current_user = @company.users.where(super_user: true).order('id asc').take
  end

  def perform
    csv_file = @csv
    headers = []

    CSV.parse(csv_file)[0].each do |h|
      headers.push h
    end
    if headers.include? 'Table Name'
      upload_tabular_information(@company, csv_file, headers)
    else
      upload_users_information(@company, csv_file, headers)
    end

    if @demo
      email = 'nigel@demo-'+ @company.domain
      user = @company.users.find_by(email: email)
      if user 
        @company.update(organization_root_id: user.id)
      end
    end
  end

  private

  def set_custom_field user, custom_field, entry
    entry = Date.strptime(entry, '%m/%d/%Y') if custom_field.field_type == 'date'
    CustomFieldValue.set_custom_field_value(user, custom_field.name, entry)
  end

  def get_custom_field(header, id = nil)
    custom_field = nil
    header = header.strip
    custom_field = @company.custom_fields.where('name ILIKE ?', header ).first if id.blank?
    custom_field = @company.custom_fields.where('name ILIKE ? AND custom_table_id = ?', header, id).first if id.present?
    custom_field
  end

  def get_sub_custom_field header
    sub_custom_field = nil
    if header == 'Code'
      cf = @company.custom_fields.where(field_type: 8, name: 'Mobile Phone Number').first
      sub_custom_field = cf.sub_custom_fields.find_by(name: 'Country')
    elsif header == 'Area'
      cf = @company.custom_fields.where(field_type: 8, name: 'Mobile Phone Number').first
      sub_custom_field = cf.sub_custom_fields.find_by(name: 'Area code')
    elsif header == 'Number'
      cf = @company.custom_fields.where(field_type: 8, name: 'Mobile Phone Number').first
      sub_custom_field = cf.sub_custom_fields.find_by(name: 'Phone')
    else
      cf = @company.custom_fields.where(name: 'Home Address').first
      sub_custom_field = cf.sub_custom_fields.where('name ILIKE ?', header).first
    end
    sub_custom_field
  end

  def set_sub_custom_field_value(user, sub_custom_field, custom_field_value)
    if sub_custom_field.present? && sub_custom_field.field_type == 'short_text'
      if sub_custom_field.name == 'Country' && sub_custom_field.custom_field.field_type != 'phone'
        country = ISO3166::Country.find_country_by_alpha3(custom_field_value)
        custom_field_value = country.name if country
      end
      user_sub_custom_field_value = sub_custom_field.custom_field_values.find_or_initialize_by(user_id: user.id)
      user_sub_custom_field_value.value_text = custom_field_value
      user_sub_custom_field_value.save!
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

  def isProfileField header
    header == 'About You' || header == 'About' || header == 'Linkedin' || header == 'Github' || header == 'Twitter' || header == 'Facebook'
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

  def get_preference_field_id header, value
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

  def get_prefrence_field header, custom_table_property = nil
    field = nil
    if custom_table_property.blank?
     field =  @company.prefrences["default_fields"].select { |field| field if field['name'] == header} rescue nil
    else
      field = @company.prefrences["default_fields"].select { |field| field if field['name'] == header && field['custom_table_property'] == custom_table_property} rescue nil
    end
    field
  end

  def upload_tabular_information company, csv_file, headers
    ctus_uploaded_count = 0
    errors_count = 0
    errors_string = ""
    csv_file = open(@file_url) if @file_url.present?
    CSV.parse(csv_file, headers: true) do |row|
      entry = row.to_hash
      next if entry['Company Email'].blank? || entry['Table Name'].blank?
      email = entry['Company Email'].try(:downcase)
      if @demo
        email = email.split('@')[0]
        email = email +'@demo-'+ company.domain
      end
      user = company.users.where(email: email).first
      custom_tables = company.enable_custom_table_approval_engine ? company.custom_tables : company.custom_tables.where.not(custom_table_property: CustomTable.custom_table_properties[:general])
      custom_table = custom_tables.where('name ILIKE ?', entry['Table Name']).last
      if user && custom_table
        next if custom_table.table_type != 'standard'  && entry['Effective Date'].blank?
        begin
          ctus_uploaded_count += 1
          effective_date = Date.strptime(entry['Effective Date'], '%m/%d/%Y') rescue nil
          next if custom_table.table_type != 'standard'  && (effective_date.blank? || (effective_date.present? && effective_date.year < 2000) )
          effective_date = effective_date.strftime("%B %d, %Y") rescue nil if effective_date

          if custom_table.table_type == 'standard'
            table_user_snapshot = user.custom_table_user_snapshots.create!(custom_table_id: custom_table.id, state: 0)
          else
            params = { custom_table_id: custom_table.id, effective_date: effective_date }
            table_user_snapshot = user.custom_table_user_snapshots.where(params).take
            table_user_snapshot = user.custom_table_user_snapshots.create!(params.merge(state: CustomTableUserSnapshot.states[:queue], terminate_job_execution: true)) if table_user_snapshot.blank?
          end
          table_user_snapshot.assign_attributes(terminate_callback: true, state: CustomTableUserSnapshot.states[:queue]) if headers.include?('Employment Status') && headers.include?('Termination Date') && Date.strptime(entry['Termination Date'], '%m/%d/%Y') > Date.today && Date.strptime(entry['Effective Date'], '%m/%d/%Y') > Date.today
          table_user_snapshot.assign_attributes(request_state: CustomTableUserSnapshot.request_states[:approved]) if custom_table.is_approval_required.present?
          if headers.include?('Employment Status') && headers.include?('Termination Date')
            user.terminate_callback = true
            last_day_worked = Date.strptime(entry['Last Day Worked'], '%m/%d/%Y') rescue nil
            last_day_worked = last_day_worked.strftime("%d/%m/%Y") rescue nil if last_day_worked
            termination_date = Date.strptime(entry['Termination Date'], '%m/%d/%Y') rescue nil
            termination_date = termination_date.strftime("%d/%m/%Y") rescue nil if termination_date
            termination_type = entry['Termination Type'].try(:downcase) rescue nil
            eligible_for_rehire = entry['Eligible For Rehire'].present? ? entry['Eligible For Rehire'].try(:parameterize).try(:underscore) : 1
            user.termination_date = termination_date
            user.last_day_worked = last_day_worked
            user.termination_type = termination_type
            user.eligible_for_rehire = eligible_for_rehire
            if termination_date.present? && Date.strptime(entry['Termination Date'], '%m/%d/%Y') < Date.today
              user.current_stage = 'departed'
            end
            table_user_snapshot.update(is_terminated: true, terminated_data:  {last_day_worked: user.last_day_worked, eligible_for_rehire: user.eligible_for_rehire, termination_type: user.termination_type})
            user.save!
          end
          
          previous_latest_custom_table_user_snapshot = CustomTableUserSnapshot.get_latest_snapshot_to_applied(table_user_snapshot.user_id, table_user_snapshot.custom_table_id, table_user_snapshot.effective_date).where.not(id: table_user_snapshot.id)&.take rescue nil
          headers.each do |header|
            custom_field = get_custom_field(header, custom_table.id) rescue nil
            prefrence_field = get_prefrence_field(header, custom_table.custom_table_property)[0] rescue nil if custom_table_preference_fields.include?(header)
            if custom_field
              if header == 'Effective Date'
                table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id, custom_field_value: effective_date).first_or_create if effective_date
              elsif custom_field.field_type == 'currency' && entry[header].present?
                currency_value = ""
                currency_type = entry['Currency Type'] rescue 'USD'
                if header == 'Pay Rate'
                  currency_type = entry["Pay Rate Currency"] if entry.include?("Pay Rate Currency")
                end
                currency = entry[header].gsub(/[\s,]/ ,"").to_f if entry[header].present?
                currency_value = "#{currency_type}|#{currency}"
                snapshot = table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id).last
                if snapshot
                  snapshot.update(custom_field_value: currency_value)
                else
                  table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_field.id, custom_field_value: currency_value)
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

                #Applying previous snapshot value if no value is present
                if custom_field_value.blank?
                  custom_field_value = (previous_latest_custom_table_user_snapshot.present? && previous_latest_custom_table_user_snapshot.try(:custom_snapshots).present?) ? previous_latest_custom_table_user_snapshot.custom_snapshots.where(custom_field_id: custom_field.id).take.custom_field_value : '' rescue ''
                end

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
              if @demo && header == 'Manager'
                entry[header] = entry[header].split('@')[0]
                entry[header] = entry[header] +'@demo-'+ company.domain
              end
              custom_field_value = get_preference_field_id(header, entry[header]) if entry[header].present? && (header == 'Location' || header == @company.department || header == 'Manager')
              snapshot = table_user_snapshot.custom_snapshots.where(preference_field_id: prefrence_field['id']).last

              #Applying previous snapshot value if no value is present
              if custom_field_value.blank?
                if prefrence_field['id'].downcase.eql?('st') && (table_user_snapshot.is_terminated || table_user_snapshot.terminated_data.present?)
                  custom_field_value = 'inactive'
                else
                  custom_field_value = (previous_latest_custom_table_user_snapshot.present? && previous_latest_custom_table_user_snapshot.try(:custom_snapshots).present?) ? previous_latest_custom_table_user_snapshot.custom_snapshots.where(preference_field_id: prefrence_field['id']).take.custom_field_value : '' rescue ''
                end
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
          table_user_snapshot.save!
          
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

            if table_fields_count != current_custom_snapshots.count
              
              # Fixing impacted custom fields
              custom_table.try(:custom_fields).try(:each) do |cfs|
                next if current_custom_snapshots.where(custom_field_id: cfs.id).present?
                previous_custom_snapshot = previous_latest_custom_table_user_snapshot.try(:custom_snapshots).where(custom_field_id: cfs.id).take rescue nil
                new_custom_snapshot_value = previous_custom_snapshot.present? ? previous_custom_snapshot.custom_field_value : ''
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
                  new_custom_snapshot_value = previous_custom_snapshot.present? ? previous_custom_snapshot.custom_field_value : ''
                end

                current_custom_snapshots.create!(preference_field_id: pfs, custom_field_value: new_custom_snapshot_value)
              end
            end
          end
          ::CustomTables::ManageCsvCustomSnapshotsJob.perform_later(table_user_snapshot) if table_user_snapshot.reload.applied?
        rescue StandardError => e
          table_user_snapshot.destroy! if table_user_snapshot.custom_snapshots.count == 0
          errors_string += "<br> Row - "+ errors_count.to_s+" - Error in Uploading Tabular Data : " + e.to_s
          errors_count += 1
          next
        end
      end
    end

    response  = "Table Snapshots Uploaded : " + ctus_uploaded_count.to_s
    response += "<br><b>Errors occurred During Upload : </b><br>" + errors_string if errors_count > 0

    UserMailer.csv_user_upload_feedback_email(company , @email , response).deliver_now!
  end

  def upload_users_information company, csv_file, headers
    users_created_count = 0
    users_updated_count = 0
    errors_count = 0
    fields_updated_count = 0
    errors_string = ""

    custom_fields = company.custom_fields.pluck(:name)
    sub_custom_fields = []

    company.custom_fields.find_each do |cf|
      if CustomField.typehHasSubFields(cf.field_type)
        sub_custom_fields.push cf.sub_custom_fields.pluck(:name)
      end
    end

    email_header = ''
    email_header = 'Company Email' if headers.include? 'Company Email'
    email_header = 'Personal Email' if headers.include?('Personal Email') && email_header.blank?
    begin
      if email_header.present?
        index = 0
        csv_file = open(@file_url) if @file_url.present?
        CSV.parse(csv_file, headers: true) do |row|
          index += 1
          entry = row.to_hash
          next if entry[email_header].blank?

          team = company.teams.where(name: entry[company.department]).first_or_create if entry[company.department].present?
          location = company.locations.where(name: entry['Location']).first_or_create if entry['Location'].present?

          email = entry['Company Email'].try(:downcase) if headers.include? 'Company Email'
          personal_email = entry['Personal Email'].try(:downcase) if headers.include? 'Personal Email'
          uid = nil
          provider = nil
          user = nil
          start_date = Date.strptime(entry['Start Date'], '%m/%d/%Y')  rescue Date.yesterday
          preferred_name = entry['Preferred Name'] rescue nil
          title = entry['Job Title'] rescue nil
          state = entry['User State'].try(:downcase)
          termination_date = Date.strptime(entry['Termination Date'], '%m/%d/%Y')  rescue nil
          termination_type = entry['Termination Type'].try(:downcase) rescue nil
          last_day_worked = entry['Last Day Worked'].present? ? Date.strptime(entry['Last Day Worked'], '%m/%d/%Y') : termination_date
          eligible_for_rehire = entry['Eligible for Rehire'].present? ? entry['Eligible for Rehire'].try(:downcase) : 1
          stage =  User.current_stages[entry['Stage'].parameterize.underscore] if entry['Stage'].present?
          integration_custom_fields = {}
          if @demo
            case stage
            when 0, 1, 2, 3
              start_date = Date.today - 3.days
            when 4, 5
              start_date = Date.today - 10.days
            end 
          end
          if email_header == 'Company Email'
            email = entry[email_header].try(:downcase)
            provider = 'email'
            if @demo
              email = email.split('@')[0]
              email = email +'@demo-'+ company.domain
            end
            user = company.users.where(email: email).first
            user = company.users.where(personal_email: personal_email).first if personal_email.present? & user.blank?
          else
            personal_email = entry[email_header].try(:downcase).strip
            provider = 'personal_email'

            user = company.users.where(personal_email: personal_email).first
            user = company.users.where(personal_email: personal_email).first if email.present? & user.blank?
          end
          if user.present?
            begin
              user_updated_changes = []

              if entry['Start Date'].present? && start_date != user.start_date
                user_updated_changes.push("start_date")
                user.start_date = start_date
              end

              if personal_email.present? && user.personal_email.blank?
                user_updated_changes.push("personal_email") if personal_email != user.personal_email
                user.personal_email = personal_email
              end

              if email.present? && user.email.blank?
                user_updated_changes.push("email") if email != user.email
                user.email = email
              end

              if preferred_name.present?
                user_updated_changes.push("preferred_name") if preferred_name != user.preferred_name
                user.preferred_name = preferred_name
              end

              if stage.present? && @demo
                user_updated_changes.push("current_stage") if stage != user.current_stage
                user.current_stage = stage
              end

              if company.is_using_custom_table.blank?

                if entry[company.department].present? && team.id != user.team_id
                  user_updated_changes.push("team_id")
                  user.team_id = team.id
                end

                if entry['Location'].present? && location.id != user.location_id
                  user_updated_changes.push("location_id")
                  user.location_id = location.id
                end

                if entry['User State'] && user.state != state
                  user_updated_changes.push("state")
                  user.state = state
                end

                if entry['Job Title'].present? && title != user.title
                  user_updated_changes.push("title")
                  user.title = title
                end

                if entry['Manager'].present?
                  manager = company.users.find_by(email: entry['Manager']) || company.users.find_by(personal_email: entry['Manager'])
                  if manager.present?
                    user_updated_changes.push("manager_id")
                    user.manager = manager
                  end
                end

                user.termination_date = termination_date if headers.include?('Termination Date') && termination_date != user.termination_date
                user.last_day_worked = last_day_worked if headers.include?('Last Day Worked') && last_day_worked != user.last_day_worked
                user.termination_type = termination_type if headers.include?('Termination Type') && termination_type != user.termination_type
                user.eligible_for_rehire = eligible_for_rehire if headers.include?('Eligible for Rehire') && eligible_for_rehire != user.eligible_for_rehire
              end
              user.save!
              users_updated_count += 1
              ::IntegrationsService::UpdateIntegrationThroughFlatfile.new(user, user_updated_changes.uniq).perform if user_updated_changes.present?
            rescue StandardError => e
              errors_count += 1
              errors_string += "<br> Row - "+index.to_s+" - Error in Updating User : " + e.to_s
              next
            end
          else

            begin
              user = company.users.create!(
                first_name: entry['First Name'].gsub(/\b\w/, &:capitalize),
                last_name: entry['Last Name'].gsub(/\b\w/, &:capitalize),
                preferred_name: preferred_name,
                title: title,
                team: team,
                location: location,
                email: email,
                provider: provider,
                role: :employee,
                current_stage: stage.present? && @demo ? stage : 11,
                password: ENV['USER_PASSWORD'],
                state: 'active',
                start_date: start_date,
                termination_date: termination_date,
                termination_type: termination_type,
                last_day_worked: last_day_worked,
                eligible_for_rehire: eligible_for_rehire,
                is_form_completed_by_manager: "completed",
                super_user: false,
                onboard_email: 'company'
              )
              user.setup_calendar_event(user, 'start_date', user.company)
              user.setup_calendar_event(user, 'anniversary', user.company)
              users_created_count += 1
            rescue StandardError => e
              errors_count += 1
              errors_string += "<br> Row - "+index.to_s+" - Error in creating User : " + e.to_s
              next
            end
          end

          if user.profile.blank?
            user.create_profile!
          end

          if entry['Profile Image']
            uploade_image(user, entry['Profile Image'])
          end

          if entry['Termination Date'].present?
            user.update_column('current_stage', 6)
          end

          headers.each do |header|
            custom_field = get_custom_field(header) rescue nil
            sub_custom_field = get_sub_custom_field(header) rescue nil
            preference_field = get_prefrence_field(header)[0] rescue nil if user_info_preference_fields.include?(header)
            begin
              if custom_field && entry[header].present?
                if custom_field.field_type == 'currency'
                  currency_type = entry['Currency Type'] rescue 'USD'
                  value = entry[header]
                  set_currency_field(user, custom_field, currency_type, value)
                else
                  set_custom_field(user, custom_field, entry[header])
                end
              elsif sub_custom_field && entry[header].present?
                set_sub_custom_field_value(user, sub_custom_field, entry[header])
              elsif isProfileField(header)
                user.profile.update((header == 'About' ?  'about_you' : header.parameterize.underscore) => entry[header])
                user.profile.flush_cache
              elsif preference_field && entry[header].present?
                user.update_column('paylocity_id', entry[header]) if header == 'Paylocity ID'
              end
              fields_updated_count += 1
              integration_custom_fields[custom_field.id] =  custom_field.name if custom_field.present?              
            rescue StandardError => e
              errors_count += 1
              errors_string += "<br> Row - "+index.to_s+" - Error in Setting Custom Fields : " + e.to_s
              next
            end
          end
          ::IntegrationsService::UpdateIntegrationThroughFlatfile.new(user, [], integration_custom_fields).perform if integration_custom_fields.present?
        end

        index = 0
        csv_file = open(@file_url) if @file_url.present?
        CSV.parse(csv_file, headers: true) do |row|
          index += 1
          entry = row.to_hash
          next if entry[email_header].blank? || entry['Manager Email'].blank?
          begin
            email = entry[email_header].try(:downcase)
            manager_email = entry['Manager Email'].try(:downcase)
            if @demo
              email = email.split('@')[0]
              email = email +'@demo-'+ company.domain
              manager_email = manager_email.split('@')[0]
              manager_email = manager_email +'@demo-'+ company.domain
            end
            user = company.users.find_by(email: email)
            user = company.users.find_by(personal_email: email) if !user

            manager = company.users.find_by(email: manager_email)
            manager = company.users.find_by(personal_email: manager_email) if !manager

            if user && manager
              user.manager = manager
              user.save!
            end
          rescue StandardError => e
            errors_count += 1
            errors_string += "<br> Row - "+index.to_s+" - Error in Assigning Manager : " + e.to_s
            next
          end
        end
      end
    rescue Exception => e
      errors_count += 1
      errors_string += "<br><br> <b>General Error :</b> <br> " + e.to_s
    end
    response  = "Users Created : " + users_created_count.to_s
    response += "<br>Users Updated : " + users_updated_count.to_s
    response += "<br>Custom Fields Updated : " + fields_updated_count.to_s
    response += "<br>Total Errors occurred : " + errors_count.to_s
    response += "<br><b>Errors occurred During Upload : </b><br>" + errors_string if errors_count > 0

    UserMailer.csv_user_upload_feedback_email(company , @email , response).deliver_now!
  end
end
