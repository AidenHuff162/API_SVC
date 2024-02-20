module SaplingApiService
  class SavePendingHireProfile

    REQUIRED_ATTRIBUTES = [ 'personal_email', 'first_name', 'last_name', 'start_date', 'source' ]
    ACCEPTED_ATTRIBUTES = [ 'personal_email', 'first_name', 'last_name', 'start_date', 'source', 'preferred_name', 'location',
    'department', 'employment_status', 'status', 'job_title', 'phone_number', 'address_line_1', 'address_line_2', 'city',
    'address_state', 'zip_code', 'country', 'manager']

    def initialize(company, request, token)
      @company = company
      @manage_pending_hire_validation = ManagePendingHireValidations.new(company)
      @request = request
      @token = token
    end

    def create_pending_hire(params)
      create(params)
    end

    def update_pending_hire(params)
      update(params)
    end

    private

    def manage_pending_hire_validation(action, params, pending_hire = nil)
      if action == 'create'
        if REQUIRED_ATTRIBUTES.all? { |key| params.keys.include?(key) }.blank?
          return { message: 'Required attributes are missing.', status: 400 }
        end
      end

      if params.keys.to_set.subset?(ACCEPTED_ATTRIBUTES.to_set).blank?
        return { message: 'Invalid attributes.', status: 400 }
      end

      params.keys.each do |key|

        if [ 'personal_email' ].include?(key)
          validation = @manage_pending_hire_validation.validateEmail(key, params, pending_hire)
          return validation if validation.present?
        
        elsif [ 'first_name', 'last_name' ].include?(key)
          validation = @manage_pending_hire_validation.validateNames(key, params)
          return validation if validation.present?
        
        elsif [ 'start_date' ].include?(key)
          validation = @manage_pending_hire_validation.validateDate(key, params)
          return validation if validation.present?

        elsif [ 'status' ].include?(key)
          validation = @manage_pending_hire_validation.validateStatus(key, params)
          return validation if validation.present?

        elsif [ 'location', 'department', 'employment_status' ].include?(key)
          validation = @manage_pending_hire_validation.validateOption(key, params)
          return validation if validation.present?
        
        elsif [ 'source' ].include?(key)
          validation = @manage_pending_hire_validation.validateSource(key, params)
          return validation if validation.present?

        elsif [ 'manager' ].include?(key)
          validation = @manage_pending_hire_validation.validateManager(key, params)
          return validation if validation.present?

        end
      end

      response = { customer: {domain: @company.domain, companyID: @company.id} }
      if action == 'create'
        return response.merge!({ message: "Created.", status: 201 })
      else
        return response.merge!({ message: "Updated.", status: 200 })
      end
    end

    def transform_params(params)
      pending_hire_params = params
      pending_hire_params[:employee_type] = pending_hire_params.delete(:employment_status) if pending_hire_params.has_key?(:employment_status)
      pending_hire_params[:location_id] = @company.locations.find_by_name(pending_hire_params.delete(:location))&.id if pending_hire_params.has_key?(:location)
      pending_hire_params[:team_id] = @company.teams.find_by_name(pending_hire_params.delete(:department))&.id if pending_hire_params.has_key?(:department)
      pending_hire_params[:state] = pending_hire_params.delete(:status) if pending_hire_params.has_key?(:status)
      pending_hire_params[:title] = pending_hire_params.delete(:job_title) if pending_hire_params.has_key?(:job_title)
      pending_hire_params[:manager_id] = @company.users.where.not(current_stage: ['departed','incomplete']).find_by(email: pending_hire_params.delete(:manager), state: :active)&.id if pending_hire_params.has_key?(:manager)
      
      pending_hire_params
    end

    def remove_unnecessary_params(params, action = nil)
      params.delete(:format)
      params.delete(:controller)
      params.delete(:action)
      params.delete(:id) if action == 'update'
      
      params
    end

    def create(params)
      params = params.deep_transform_keys! { |key| key.underscore }.with_indifferent_access
      remove_unnecessary_params(params)

      validation = manage_pending_hire_validation('create', params)
      log(params.to_hash, validation[:status], validation[:message], 'Create Pending Hire')

      if validation[:status] == 201
        pending_hire_params = transform_params(params)
        pending_hire = @company.pending_hires.create!(pending_hire_params)
        pending_hire.create_user

        validation.merge!({ guid: pending_hire.guid, userID: pending_hire.user_id, userGUID: pending_hire&.user&.guid })
      end

      return validation
    end

    def update(params)
      params = params.deep_transform_keys! { |key| key.underscore }.with_indifferent_access
      pending_hire = @company.pending_hires.where(guid: params[:id]).take

      if pending_hire.present?
        remove_unnecessary_params(params, 'update')

        validation = manage_pending_hire_validation('update', params, pending_hire)
        log(params.to_hash, validation[:status], validation[:message], 'Update Pending Hire')
        
        if validation[:status] == 200
          pending_hire_params = transform_params(params)
          pending_hire.update!(pending_hire_params)
          pending_hire.update_user if pending_hire.user_id.present?

          validation.merge!({ guid: pending_hire.guid, userID: pending_hire.user_id, userGUID: pending_hire&.user&.guid })
        end
        
        return validation
      else
        log(params.to_hash, 400, 'Invalid PendingHire ID', 'Update Pending Hire')
        return { message: 'Invalid PendingHire ID', status: 400 }
      end
    end

    def create_sapling_api_logging(data, status, message, location)
      @sapling_api_logging ||= LoggingService::SaplingApiLogging.new
      @sapling_api_logging.create(@company, @token, @request.url, data, status, message, location)
    end

    def log_integration_statistics(status)
      @integration_statistics ||= ::RoiManagementServices::IntegrationStatisticsManagement.new
      
      if [ 200, 201 ].include?(status) 
        @integration_statistics.log_success_api_calls_statistics(@company)
      else
        @integration_statistics.log_failed_api_calls_statistics(@company)
      end
    end

    def log(data, status, message, location)
      create_sapling_api_logging(data, status.to_s, message, location)
      log_integration_statistics(status)
    end
  end
end