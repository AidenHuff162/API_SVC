class BulkOnboardUsersService 
   def perform(params, company_id, current_user_id)
      begin
        @company = Company.find_by(id: company_id)
        @pending_hire_users = params['pending_hires']
        bulk_onboard_users(params, current_user_id) if @pending_hire_users
        destroy_pending_hires unless params['is_rehired']    
      rescue Exception => e
        unless params['is_rehired']
          @company.pending_hires.where(id: @pending_hire_users.pluck('id')).update_all(state: 'active') rescue nil
        end
        handle_error(e, params)
      end
    end

    private

    def bulk_onboard_users(params, current_user_id)
      @current_user = @company.users.find_by(id: current_user_id)
      @custom_sections = params['custom_sections']
      @custom_tables = params['custom_tables']
      @tasks = params['tasks']
      @template_ids = params['template_ids']
      @documents =  params['pt_dur']
      @documents_count = @documents.length rescue 0
      @workstream_count = params['workstream_count']
      @users = []
      @managers = {}
      @user_tokens = {}
      create_users(params)
      cancel_offboarding if params['is_rehired'].present?
      assign_custom_field_values
      @user_ids = @users.map{|user| user.id}
      BulkOnboardingAssignDocumentsJob.perform_async(@documents, @user_ids, @current_user.id, @company.id, @user_tokens)
      create_onboard_custom_snapshots unless params['is_rehired'].present?
      create_rehired_user_snapshots if params['is_rehired'].present?
      assign_tasks
      send_email_to_users(params['is_rehired'], current_user_id, params["selected_template_id"])
      start_bulk_onboard_webhook(current_user_id, @user_ids)
    end

    def start_bulk_onboard_webhook(current_user_id, user_ids)
      @user_ids.each do |user_id|
        WebhookEventServices::ManageWebhookEventService.new.initialize_event(@company, {event_type: 'onboarding' ,type: 'onboarding', stage: 'started', triggered_for: user_id, triggered_by: @current_user.id, user_id: user_id  })
      end
    end

    def create_users(params)
      @pending_hire_users.each do |pending_hire_user|
        user_hash = {
          company_id: @company.id,
          first_name: pending_hire_user["first_name"],
          preferred_name: pending_hire_user["preferred_name"],
          last_name: pending_hire_user["last_name"],
          email: pending_hire_user["email"],
          personal_email: pending_hire_user["personal_email"],
          title: pending_hire_user["title"],
          location_id: pending_hire_user["location_id"],
          team_id: pending_hire_user["team_id"],
          start_date: pending_hire_user["start_date"],
          manager_id: pending_hire_user["manager_id"],
          workday_id: pending_hire_user["workday_id"],
          onboard_email: params["onboard_email"],
          provision_gsuite: params["provision_accounts"],
          send_credentials_type: params["send_credentials_type"],
          send_credentials_time: params["send_credentials_time"],
          send_credentials_timezone: params["send_credentials_timezone"],
          send_credentials_offset_before: params["send_credentials_offset_before"],
          smart_assignment: true,
          onboarding_profile_template_id: params["selected_template_id"],
          account_creator_id: @current_user.id
        }
        unless pending_hire_user["user_id"] || params['is_rehired'].present?
          user = save_user(user_hash)
        else
          user = User.find_by(id: params['is_rehired'].present? ? pending_hire_user["id"] : pending_hire_user["user_id"])
          user_hash[:id] = user.id
          user = save_user(user_hash)
        end
        @managers.key?(user.manager_id) ? (@managers[user.manager_id].push(user.id)) : (@managers[user.manager_id] = [user.id]) if user.manager.present?
        user.pending_hire_id = pending_hire_user["id"]
        CustomFieldValue.set_custom_field_value(user, "Employment Status", pending_hire_user["employee_type"]) if pending_hire_user["employee_type"]
        @users << user
        @user_tokens[user.id.to_s] = SecureRandom.uuid + "-" + DateTime.now.to_s
        true
      end
    end

    def send_email_to_users(is_rehired, current_user_id, onboarding_profile_template_id)
      #Send emails to the manager @managers
      BulkOnboardingPeterEmailJob.perform_async(@managers)
      #Send emails to the users
      LoggingService::GeneralLogging.new.create(@company, 'Bulk-onboarding', {email_templates_id: @template_ids, documents_ids: @documents, user_ids: @user_ids, users: @users})
      batch = Sidekiq::Batch.new
      batch.on(:complete, 'BulkOnboardingSuccess#on_complete', {user_id: @current_user.id, users_count: @users.length, workstream_count: @workstream_count, template_count: @template_ids.length, is_rehired: is_rehired})
      batch.jobs do
        @users.each { |user| BulkOnboardingEmailsJob.perform_async(user.id, @template_ids, current_user_id, onboarding_profile_template_id) }
      end
    end

    def assign_field_value(field, user)
      value = nil
      if field["isDefault"]
        if field["id"] == "bdy"
          if field["state"] == "bulk"
            value = field["custom_field_value"]["coworker_id"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"]["coworker_id"] rescue nil
          end
          user.update(buddy_id: value) if value
        elsif field["id"] == "abt"
          if field["state"] == "bulk"
            value = field["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"] rescue nil
          end
          user.profile.update(about_you: value) if value
        elsif field["id"] == "lin"
          if field["state"] == "bulk"
            value = field["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"] rescue nil
          end
          user.profile.update(linkedin: value) if value
        elsif field["id"] == "twt"
          if field["state"] == "bulk"
            value = field["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"] rescue nil
          end
          user.profile.update(twitter: value) if value
        elsif field["id"] == "gh"
          if field["state"] == "bulk"
            value = field["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"] rescue nil
          end
          user.profile.update(github: value) if value
        end
      else
        if ["short_text", "long_text", "simple_phone", "social_security_number", "social_insurance_number", "number", "date", "confirmation"].include?(field["field_type"])
          if field["state"] == "bulk"
            value = field["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"] rescue nil
          end
          CustomFieldValue.set_custom_field_value(user, field["name"], value) if value
        elsif field["field_type"] == "mcq"
          if field["state"] == "bulk"
            value = CustomFieldOption.find(field["custom_field_value"]["custom_field_option_id"]).option rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = CustomFieldOption.find(field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"]).option rescue nil
          end
          CustomFieldValue.set_custom_field_value(user, field["name"], value) if value
        elsif field["field_type"] == "coworker"
          if field["state"] == "bulk"
            value = field["custom_field_value"]["coworker_id"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"]["coworker_id"] rescue nil
          end
          CustomFieldValue.set_custom_field_value(user, field["name"], value) if value
        elsif field["field_type"] == "currency"
          custom_field = @company.custom_fields.find_by(id: field["id"])
          if field["state"] == "bulk"
            type_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Currency Type" }[0]["custom_field_value"]["value_text"] rescue nil
            value_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Currency Value" }[0]["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            type_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Currency Type" }[0]["custom_field_value"]["value_text"] rescue nil
            value_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Currency Value" }[0]["custom_field_value"]["value_text"] rescue nil
          end
          CustomFieldValue.set_custom_field_value(user, nil, type_value, 'Currency Type', false, custom_field) if type_value
          CustomFieldValue.set_custom_field_value(user, nil, value_value, 'Currency Value', false, custom_field) if value_value
        elsif field["field_type"] == "tax"
          custom_field = @company.custom_fields.find_by(id: field["id"])
          if field["state"] == "bulk"
            type_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Tax Type" }[0]["custom_field_value"]["value_text"] rescue nil
            value_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Tax Value" }[0]["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            type_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Tax Type" }[0]["custom_field_value"]["value_text"] rescue nil
            value_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Tax Value" }[0]["custom_field_value"]["value_text"] rescue nil
          end
          CustomFieldValue.set_custom_field_value(user, nil, type_value, 'Tax Type', false, custom_field) if type_value
          CustomFieldValue.set_custom_field_value(user, nil, value_value, 'Tax Value', false, custom_field) if value_value
        elsif field["field_type"] == "phone"
          custom_field = @company.custom_fields.find_by(id: field["id"])
          if field["state"] == "bulk"
            country_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Country" }[0]["custom_field_value"]["value_text"] rescue nil
            area_code_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Area code" }[0]["custom_field_value"]["value_text"] rescue nil
            phone_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Phone" }[0]["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            country_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Country" }[0]["custom_field_value"]["value_text"] rescue nil
            area_code_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Area code" }[0]["custom_field_value"]["value_text"] rescue nil
            phone_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Phone" }[0]["custom_field_value"]["value_text"] rescue nil
          end
          CustomFieldValue.set_custom_field_value(user, nil, country_value, 'Country', false, custom_field) if country_value
          CustomFieldValue.set_custom_field_value(user, nil, area_code_value, 'Area Code', false, custom_field) if area_code_value
          CustomFieldValue.set_custom_field_value(user, nil, phone_value, 'Phone', false, custom_field) if phone_value
        elsif field["field_type"] == "address"
          custom_field = @company.custom_fields.find_by(id: field["id"])
          if field["state"] == "bulk"
            line1_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Line 1" }[0]["custom_field_value"]["value_text"] rescue nil
            line2_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Line 2" }[0]["custom_field_value"]["value_text"] rescue nil
            city_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "City" }[0]["custom_field_value"]["value_text"] rescue nil
            state_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "State" }[0]["custom_field_value"]["value_text"] rescue nil
            zip_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Zip" }[0]["custom_field_value"]["value_text"] rescue nil
            country_value = field["sub_custom_fields"].select { |sub_field| sub_field["name"] == "Country" }[0]["custom_field_value"]["value_text"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            line1_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Line 1" }[0]["custom_field_value"]["value_text"] rescue nil
            line2_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Line 2" }[0]["custom_field_value"]["value_text"] rescue nil
            city_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "City" }[0]["custom_field_value"]["value_text"] rescue nil
            state_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "State" }[0]["custom_field_value"]["value_text"] rescue nil
            zip_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Zip" }[0]["custom_field_value"]["value_text"] rescue nil
            country_value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].select { |sub_field| sub_field["name"] == "Country" }[0]["custom_field_value"]["value_text"] rescue nil
          end
          CustomFieldValue.set_custom_field_value(user, nil, line1_value, 'Line 1', false, custom_field) if line1_value
          CustomFieldValue.set_custom_field_value(user, nil, line2_value, 'Line 2', false, custom_field) if line2_value
          CustomFieldValue.set_custom_field_value(user, nil, city_value, 'City', false, custom_field) if city_value
          CustomFieldValue.set_custom_field_value(user, nil, state_value, 'State', false, custom_field) if state_value
          CustomFieldValue.set_custom_field_value(user, nil, zip_value, 'Zip', false, custom_field) if zip_value
          CustomFieldValue.set_custom_field_value(user, nil, country_value, 'Country', false, custom_field) if country_value
        elsif field["field_type"] == "multi_select"
          if field["state"] == "bulk"
            value = field["custom_field_value"]["checkbox_values"] rescue nil
          elsif field["state"] == "individual" || field["state"] == "auto"
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"].map do |custom_field_option|
              custom_field_option["is_selected"] ? custom_field_option["id"] : nil
            end if field["name"] != "Google Groups" rescue nil
            value = field["individual_values"][user.pending_hire_id.to_s]["custom_field_value"] if field["name"] == "Google Groups" rescue nil
            value = value.try(:compact)
          end
          CustomFieldValue.set_custom_field_value(user, field["name"], value) if value
        end
      end
    end

    def assign_custom_field_values
      @users.each do |user|
        @custom_sections.each do |section|
          section["custom_fields"].try(:each) do |field|
            field_name = nil
            #remove this if check if we need to send the updates for all of the fields to integration. Currently we are syncing google organization units to gsuite.
            if field['name'] == 'Google Organization Unit'
              custom_field_value = user.custom_field_values.find_by(custom_field_id: field['id'])
              field_name = get_field_name_needs_to_be_updated(field, custom_field_value) 
            end
            assign_field_value(field, user)
            send_update_to_integrations(user, field_name) if field_name.present?
          end
        end
        @custom_tables.try(:each) do |table|
          table["custom_fields"].try(:each) do |field|
            assign_field_value(field, user)
          end
        end
      end
    end

    def create_onboard_custom_snapshots
      @users.each do |user|
        ::CustomTables::CustomTableSnapshotManagement.new.onboarding_management(@current_user, user, @company) if user.present? && @current_user.present?
      end
    end

    def assign_tasks
      @users.each do |user|
        user.task_user_connections.draft_connections.destroy_all
        assign_params = @tasks.map { |task| task.deep_symbolize_keys }
        Interactions::TaskUserConnections::Assign.new(user, assign_params, false, false, nil, @current_user.id).perform
      end
      true
    end
    
    def save_user(user_hash)
      form = UserForm.new(user_hash)
      form.save!
      form.user
    end

    def handle_error(e, params)
      puts "error encountered"
      p e
      LoggingService::GeneralLogging.new.create(@company, 'Bulk-onboarding', {result: 'Failed bulk onboarding', error: e.message, params: params})
      true
    end

    def cancel_offboarding
      @users.each do |user|
        user.update_column(:is_rehired, true)
        ::IntegrationsService::UserIntegrationOperationsService.new(user).perform('reactivate')
        user.cancel_offboarding
      end
    end

    def create_rehired_user_snapshots
      @users.each do |user|
        ::CustomTables::CustomTableSnapshotManagement.new.rehiring_management(user, @current_user) if user.present? && @current_user.present?
      end
    end

    def send_update_to_integrations(user, field_name)
      user.reload

      manage_gsuite_update(user, @company, {google_groups: true}) if @company.google_groups_feature_flag
    end

    def get_field_name_needs_to_be_updated(update_custom_field_params, custom_field_value)
      if update_custom_field_params['custom_field_value'].present?
        value_text = update_custom_field_params['custom_field_value']['value_text'] rescue nil
        custom_field_option_id = update_custom_field_params['custom_field_value']['custom_field_option_id'] rescue nil
        if (custom_field_value.present? && ( value_text != custom_field_value.value_text || custom_field_option_id != custom_field_value.custom_field_option_id )) || (custom_field_value.blank? && (value_text.present? || custom_field_option_id.present?))
          return update_custom_field_params['name']
        end
      end
    end

    def destroy_pending_hires
      pending_hire_ids = onboarded_pending_hire_ids
      @company.pending_hires.where(id: pending_hire_ids).destroy_all
      PendingHire.create_general_logging(@company, 'Bulk-onboarding', { action: 'destroy pending hire',
                                                                        pending_hire_ids: pending_hire_ids,
                                                                        time: DateTime.current.utc })
    end
    
    def onboarded_pending_hire_ids
      @company.reload
      @company.pending_hires.where(id: @pending_hire_users.pluck('id')).update_all(state: 'active')
      update_onboarded_user_current_stage

      pending_hire_personal_emails = @pending_hire_users.pluck('personal_email').compact.map(&:downcase)
      user_personal_emails = @company.users.where(personal_email: pending_hire_personal_emails).pluck('personal_email')
      @pending_hire_users.select { |user| user_personal_emails.include?(user['personal_email']) }.pluck('id')
    end
  end

  def manage_gsuite_update(user, company, params)
    return unless company.get_gsuite_account_info.present? && (company.subdomain == 'warbyparker' || Rails.env.staging?)
      
    if !user.incomplete? && (params.key?(:google_groups))
      ::SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob.perform_later(user.id, params.key?(:google_groups))
    end
  end

  def update_onboarded_user_current_stage
    @onboarding_users = @company.users.where(email: @pending_hire_users.pluck('email'))
    @onboarding_users.each do |user|
      user.invite!
      user.save
    end
  end

  class BulkOnboardingSuccess
    def on_complete(status, options)
      user = User.find_by(id: options['user_id'])
      email_data = {customer_brand: "#3F1DCB", customer_logo: user.company.logo, new_hire_count: options['users_count'],
        total_sent_emails_cont: (options['users_count'].to_i * options['template_count'].to_i), total_assigned_workflows_cont: (options['users_count'].to_i * options['workstream_count'].to_i),
        dashboard_url: 'https://' + user.company.app_domain + '/#/admin/dashboard/onboarding', receiver_name: user.display_name, is_rehired: options['is_rehired']
      }
      UserMailer.bulk_onboarding_email_for_sarah_or_peter(options['user_id'], email_data, true).deliver_later!
    end
end