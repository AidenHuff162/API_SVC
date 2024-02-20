module SaplingApiService
  class SaveUserProfile
    attr_reader :company, :manage_user_validation, :request, :token, :role_information, :employment_status

    DEFAULT_API_FIELDS_ID = [ 'first_name', 'last_name', 'preferred_name', 'job_title', 'job_tier', 'manager', 'location',
      'department', 'start_date', 'termination_date', 'status', 'last_day_worked', 'company_email', 'personal_email',
      'about', 'profile_photo', 'github', 'facebook', 'twitter', 'linkedin'
    ]
    REQUIRED_API_FIELDS_ID = [ 'company_email', 'first_name', 'last_name', 'start_date' ]

    def initialize(company, request, token)
      @company = company
      @manage_user_validation = ManageUserValidations.new(company)
      @request = request
      @token = token
      @role_information = CustomTable.role_information(company.id)
      @employment_status = CustomTable.employment_status(company.id)
    end

    def update_user(params)
      update(params)
    end

    def fetch_custom_fields(params, company)
      company.custom_fields.where('lower(api_field_id) IN (?)', params.keys) if company.present?
    end

    def create_user(params)
      create(params)
    end

    private

    def manage_user_for_updation(params, user)
      set = params.keys
      if !set.present?
        create_sapling_api_logging(params.to_hash, '400', 'Attributes required for updates', 'Service::SaplingApiService::SaveUserProfile/manage_user_for_updation')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
        return { message: 'Attributes required for updates', status: 400 }
      end
      old_custom_field_data = []
      custom_fields = fetch_custom_fields(params, company)
      
      custom_fields.each do |custom_field|
        old_value = user.get_custom_field_value_text(custom_field.name)
        old_custom_field_data.push({name: custom_field.name, old_value: old_value})
      end
      parent_set = custom_fields.pluck(:api_field_id).map!(&:downcase).concat(DEFAULT_API_FIELDS_ID)

      if !set.to_set.subset?(parent_set.to_set)
        create_sapling_api_logging(params.to_hash, '422', 'Invalid attributes', 'Service::SaplingApiService::SaveUserProfile/manage_user_for_updation')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
        return { message: 'Invalid attributes', status: 422 }
      end
      validate_user_data = manage_user_data_validations(params, custom_fields, user)
      return validate_user_data if validate_user_data.present? && validate_user_data[:message].present?
  
      is_role_information_changed = role_info_changed(user, validate_user_data) if role_information.present?
      is_employment_status_changed = employment_status_changed(user, validate_user_data) if employment_status.present?
      temp_user = User.find_by(id: user.id)
      temp_profile = User.find_by(id: user.id)&.profile
      temp_profile.id = temp_profile&.user_id
      user.update!(validate_user_data) if !validate_user_data[:message].present?
      
      manage_preference_fields_ctus(user, is_role_information_changed, is_employment_status_changed) if is_role_information_changed.present? || is_employment_status_changed.present?
      create_or_update_user_custom_fields(params, user, custom_fields)
      default_data_change = validate_user_data.keys
      default_data_change = validate_user_data[:profile_attributes]&.stringify_keys&.keys + default_data_change if validate_user_data.has_key?(:profile_attributes)
      default_data_change.delete(:profile_attributes) if validate_user_data.has_key?(:profile_attributes)
      
      validate_user_data.has_key?(:profile_attributes)
      create_sapling_api_logging(params.to_hash, '200', 'Updated successfully', 'Service::SaplingApiService::SaveUserProfile/manage_user_for_updation')

      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_api_calls_statistics(@company)
      begin
        WebhookEvents::ManageWebhookPayloadJob.perform_async(company.id, {default_data_change: default_data_change, user: user.id, temp_user: temp_user.attributes, webhook_custom_field_data: old_custom_field_data, temp_profile: temp_profile.attributes})
      rescue Exception => e
        puts e.message
      end
      return { message: 'Updated successfully', id: user.guid, status: 200 }
    end

    def manage_user_for_creation(params)
      set = params.keys
      custom_fields = fetch_custom_fields(params, company)
      if !REQUIRED_API_FIELDS_ID.all?{|key| params.keys.include?(key)}
        create_sapling_api_logging(params.to_hash, '422', 'Required attributes are missing', 'Service::SaplingApiService::SaveUserProfile/manage_user_for_creation')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
        return { message: 'Required attributes are missing' }
      end
      parent_set = custom_fields.pluck(:api_field_id).map!(&:downcase).concat(DEFAULT_API_FIELDS_ID)
      if !set.to_set.subset?(parent_set.to_set)
        create_sapling_api_logging(params.to_hash, '422', 'Invalid attributes', 'Service::SaplingApiService::SaveUserProfile/manage_user_for_creation')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
        return { message: 'Invalid attributes', status: 422 }
      end
      validate_user_data = manage_user_data_validations(params, custom_fields)
      return validate_user_data if validate_user_data.present? && validate_user_data[:message].present?
      validate_user_data.merge!(current_stage: "registered")
      user = company.users.create!(validate_user_data) if !validate_user_data[:message].present?
      
      is_role_information_changed = true if role_information.present? && (validate_user_data.keys & [:location_id, :manager_id, :team_id, :title]).present?
      is_employment_status_changed = true if employment_status.present? && (validate_user_data.keys & [:termination_date, :last_day_worked, :state]).present?
      
      manage_preference_fields_ctus(user, is_role_information_changed, is_employment_status_changed) if is_role_information_changed.present? || is_employment_status_changed.present?
      create_or_update_user_custom_fields(params, user, custom_fields)

      create_sapling_api_logging(params.to_hash, '200', 'Created successfully', 'Service::SaplingApiService::SaveUserProfile/manage_user_for_creation')
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_api_calls_statistics(@company)
      return { message: "Created successfully", guid: user.guid, status: 200 }
    end

    def create_or_update_user_custom_fields(params, user, custom_fields)
      custom_fields.try(:find_each) do |custom_field|
        update_custom_table = custom_field.custom_table.present? && is_custom_field_value_updated?(custom_field, user, params)
        api_field_id = custom_field.api_field_id&.downcase
        
        if custom_field.address?
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:line_1], 'Line 1', false, custom_field)
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:line_2], 'Line 2', false, custom_field)
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:city], 'City', false, custom_field)
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:country], 'Country', false, custom_field)
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:zip], 'Zip', false, custom_field)
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:state], 'State', false, custom_field)
        elsif custom_field.phone?
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:area_code], 'Area Code', false, custom_field) if params[api_field_id][:area_code].present?
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:phone], 'Phone', false, custom_field) if params[api_field_id][:phone].present?
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:country], 'Country', false, custom_field) if params[api_field_id][:country].present?
        elsif custom_field.currency?
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:currency_type], 'Currency Type', false, custom_field) if params[api_field_id][:currency_type].present?
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id][:currency_value], 'Currency Value', false, custom_field) if params[api_field_id][:currency_value].present?
        else
          CustomFieldValue.set_custom_field_value(user, custom_field.name, params[api_field_id], nil, true, custom_field)
        end

        CustomTables::CustomTableSnapshotManagement.new.public_api_management(custom_field.custom_table, user.reload) if update_custom_table.present?
      end
    end

    def manage_user_data_validations(params, custom_fields, user = nil)
      if custom_fields.present?
        date_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:date], params.keys)
        coworker_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:coworker], params.keys)
        ssn_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:social_security_number], params.keys)
        sin_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:social_insurance_number], params.keys)
        option_type_custom_fields = custom_fields.where("field_type IN (?) AND lower(api_field_id) IN (?)", [CustomField.field_types[:mcq], CustomField.field_types[:employment_status], CustomField.field_types[:multi_select]], params.keys)
        address_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:address], params.keys)
        international_phone_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:phone], params.keys)
        number_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:number], params.keys)
        currency_type_custom_fields = custom_fields.where("field_type = ? AND lower(api_field_id) IN (?)", CustomField.field_types[:currency], params.keys)
      end

      user_params = {}

      params.keys.each do |key|
        if ['company_email', 'personal_email'].include?(key)
          email_validation = manage_user_validation.validateEmail(key, params, user)

          if email_validation.present?
            create_sapling_api_logging(params.to_hash, '400', email_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return email_validation
          end

          if key == 'company_email'
            user_params[:email] = params[key]
          else
            user_params["#{key}"] = params[key]
          end

        elsif ['first_name', 'last_name'].include?(key)
          names_validation = manage_user_validation.validateNames(key, params)

          if names_validation.present?
            create_sapling_api_logging(params.to_hash, '400', names_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return names_validation
          end

          user_params["#{key}"] = params[key]

        elsif ['start_date', 'termination_date', 'last_day_worked'].include?(key)
          date_validation = manage_user_validation.validateDate(key, params)

          if date_validation.present?
            create_sapling_api_logging(params.to_hash, '400', date_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return date_validation
          end

          user_params["#{key}"] = params[key]

        elsif key == 'status'
          status_validation = manage_user_validation.validateStatus(key, params)

          if status_validation.present?
            create_sapling_api_logging(params.to_hash, '400', status_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return status_validation
          end

          user_params[:state] = params[key]

        elsif key == 'manager'
          guid_validation = manage_user_validation.validateGuid(key, params, nil, user)

          if guid_validation.present?
            create_sapling_api_logging(params.to_hash, '400', guid_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return guid_validation
          end

          user_params[:manager_id] = company.users.find_by(guid: params[key]).try(:id)

        elsif ['location', 'department'].include?(key)
          option_validation = manage_user_validation.validateOption(key, params, nil)

          if option_validation.present?
            create_sapling_api_logging(params.to_hash, '400', option_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return option_validation
          end

          if key == 'location'
            user_params[:location_id] = company.locations.find_by(name: params[key]).try(:id)
          else
            user_params[:team_id] = company.teams.find_by(name: params[key]).try(:id)
          end
        elsif ['preferred_name'].include?(key)
          user_params[:preferred_name] = params[key]

        elsif ['job_title'].include?(key)
          user_params[:title] = ActionView::Base.full_sanitizer.sanitize(params[key])
          
        elsif ['about', 'github', 'facebook', 'twitter', 'linkedin'].include?(key)
          user_params[:profile_attributes] ||= assign_profile_attributes(user)
          
          if ['about'].include?(key)
            user_params[:profile_attributes][:about_you] = params[key]

          elsif ['github'].include?(key)
            user_params[:profile_attributes][:github] = params[key]

          elsif ['facebook'].include?(key)
            user_params[:profile_attributes][:facebook] = params[key]

          elsif ['twitter'].include?(key)
            user_params[:profile_attributes][:twitter] = params[key]

          elsif ['linkedin'].include?(key)
            user_params[:profile_attributes][:linkedin] = params[key]
          end

        elsif ['profile_photo'].include?(key)
          image_validation = manage_user_validation.validateFile(key, params)

          if image_validation.present? && image_validation[:message].present?
            create_sapling_api_logging(params.to_hash, '400', image_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return image_validation
          end
          user_params[:profile_image] = image_validation if image_validation&.file.present?

        elsif date_type_custom_fields.present? && date_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          date_validation = manage_user_validation.validateDate(key, params, date_type_custom_fields.pluck(:api_field_id))

          if date_validation.present?
            create_sapling_api_logging(params.to_hash, '400', date_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return date_validation
          end

        elsif ssn_type_custom_fields.present? && ssn_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          ssn_validation = manage_user_validation.validateSSN(key, params, ssn_type_custom_fields.pluck(:api_field_id))

          if ssn_validation.present?
            create_sapling_api_logging(params.to_hash, '400', ssn_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return ssn_validation
          end

        elsif sin_type_custom_fields.present? && sin_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          sin_validation = manage_user_validation.validateSIN(key, params, sin_type_custom_fields.pluck(:api_field_id))
          
          if sin_validation.present?
            create_sapling_api_logging(params.to_hash, '400', sin_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return sin_validation
          end

        elsif coworker_type_custom_fields.present? && coworker_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          guid_validation = manage_user_validation.validateGuid(key, params, coworker_type_custom_fields.pluck(:api_field_id), user)

          if guid_validation.present?
            create_sapling_api_logging(params.to_hash, '400', guid_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return guid_validation
          end

        elsif option_type_custom_fields.present? && option_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          option_validation = manage_user_validation.validateOption(key, params, option_type_custom_fields)

          if option_validation.present?
            create_sapling_api_logging(params.to_hash, '400', option_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return option_validation
          end

        elsif address_type_custom_fields.present? && address_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          address_validation = manage_user_validation.validateAddress(key, params)

          if address_validation.present?
            create_sapling_api_logging(params.to_hash, '400', address_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return address_validation
          end

        elsif international_phone_type_custom_fields.present? && international_phone_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          internation_phone_validation = manage_user_validation.validateInternationPhone(key, params)

          if internation_phone_validation.present?
            create_sapling_api_logging(params.to_hash, '400', internation_phone_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return internation_phone_validation
          end

        elsif currency_type_custom_fields.present? && currency_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          currency_validation = manage_user_validation.validateCurrency(key, params)

          if currency_validation.present?
            create_sapling_api_logging(params.to_hash, '400', currency_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return currency_validation
          end

        elsif number_type_custom_fields.present? && number_type_custom_fields.pluck(:api_field_id).map!(&:downcase).include?(key)
          number_validation = manage_user_validation.validateNumber(key, params)

          if number_validation.present?
            create_sapling_api_logging(params.to_hash, '400', number_validation[:message], 'Service::SaplingApiService::SaveUserProfile/manage_user_data_validations')
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
            return number_validation
          end
        end
      end

      return user_params
    end

    def assign_profile_attributes(user)
      { about_you: user&.profile&.about_you, facebook: user&.profile&.facebook, twitter: user&.profile&.twitter, linkedin: user&.profile&.linkedin, github: user&.profile&.github }
    end

    def create(params)
      params.delete(:format)
      params.delete(:controller)
      params.delete(:action)

      return manage_user_for_creation(params)
    end

    def update(params)
      user = company.users.where(guid: params[:id]).first

      if user.present?
        params.delete(:format)
        params.delete(:controller)
        params.delete(:action)
        params.delete(:id)

        return manage_user_for_updation(params, user)
      else
        create_sapling_api_logging(params.to_hash, '400', I18n.t("api_notification.invalid_user_id"), 'Service::SaplingApiService::SaveUserProfile/update')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_api_calls_statistics(@company)
        return { message: I18n.t("api_notification.invalid_user_id"), status: 400 }
      end
    end

    def create_sapling_api_logging data, status, message, location
      @sapling_api_logging ||= LoggingService::SaplingApiLogging.new
      @sapling_api_logging.create(@company, @token, @request.url, data, status, message, location)
    end
    
    def manage_preference_fields_ctus(user, role_info_changed, employment_status_changed)
      if role_info_changed.present?
        CustomTables::CustomTableSnapshotManagement.new.public_api_management(role_information, user) if role_information.present?
      end

      if employment_status_changed.present? 
        CustomTables::CustomTableSnapshotManagement.new.public_api_management(employment_status, user) if employment_status.present?
      end
    end

    def employment_status_changed user, validate_user_data
      is_employment_status_changed = false
      
      if (validate_user_data.keys & [:termination_date, :last_day_worked, :state]).present?
        is_employment_status_changed = true if (validate_user_data[:termination_date].present? && user.termination_date != validate_user_data[:termination_date]) || 
          (validate_user_data[:last_day_worked].present? && user.last_day_worked != validate_user_data[:last_day_worked]) ||
          (validate_user_data[:state].present? && user.state != validate_user_data[:state])
      end

      return is_employment_status_changed
    end

    def role_info_changed user, validate_user_data
      is_role_information_changed = false
      
      if (validate_user_data.keys & [:location_id, :manager_id, :team_id, :title]).present?
        is_role_information_changed = true if (validate_user_data[:location_id].present? && user.location_id != validate_user_data[:location_id]) || 
          (validate_user_data[:location_id].present? && user.manager_id != validate_user_data[:manager_id]) ||
          (validate_user_data[:team_id].present? && user.team_id != validate_user_data[:team_id]) || 
          (validate_user_data[:title].present? && user.title != validate_user_data[:title])
      end
      
      return is_role_information_changed
    end

    def is_custom_field_value_updated?(custom_field, user, params)
      is_changed = false
      api_field_id = custom_field.api_field_id&.downcase

      if custom_field.phone?
        is_changed = true if CustomField.get_sub_custom_field_value(custom_field, 'Area Code', user.id) != params[api_field_id][:area_code].to_s|| 
          CustomField.get_sub_custom_field_value(custom_field, 'Phone', user.id) != params[api_field_id][:phone].to_s || CustomField.get_sub_custom_field_value(custom_field, 'Country', user.id) != params[custom_field.api_field_id][:country].to_s
      elsif custom_field.currency?
        is_changed = true if CustomField.get_sub_custom_field_value(custom_field, 'Currency Type', user.id) != params[api_field_id][:currency_type].to_s || 
          CustomField.get_sub_custom_field_value(custom_field, 'Currency Value', user.id) != params[api_field_id][:currency_value].to_s
      else
        is_changed = true if custom_field.mcq? && CustomField.get_mcq_custom_field_value(custom_field, user.id) != params[api_field_id].to_s
        is_changed = true if custom_field.coworker? && CustomField.get_coworker_value(custom_field, user.id)&.guid != params[api_field_id].to_s
        is_changed = true if !custom_field.mcq? && !custom_field.coworker? && !custom_field.address? && CustomField.get_custom_field_value(custom_field, user.id) != params[api_field_id].to_s
      end

      return is_changed
    end
  end
end
