module SaplingApiService
  class RetrievePendingHireProfile

    def initialize(company, request, token)
      @company = company
      @request = request
      @token = token
    end

    def fetch_pending_hires(params)
      prepare_pending_hires_data_hash(params)
    end

    def fetch_pending_hire(params)
      prepare_pending_hire_data_hash(params)
    end

    private

    def prepare_hash(pending_hire)
      data = { 
        pendingHireID: pending_hire.guid,
        startDate: pending_hire.start_date,
        firstName: pending_hire.first_name,
        lastName: pending_hire.last_name,
        status: pending_hire.state,
        employmentStatus: pending_hire.employee_type,
        preferredName: pending_hire.preferred_name,
        personalEmail: pending_hire.personal_email,
        source: pending_hire.source,
        location: pending_hire.location&.name,
        department: pending_hire.team&.name,
        jobTitle: pending_hire.title,
        phoneNumber: pending_hire.phone_number,
        addressLine1: pending_hire.address_line_1,
        addressLine2: pending_hire.address_line_2,
        city: pending_hire.city,
        addressState: pending_hire.address_state,
        zipCode: pending_hire.zip_code,
        country: pending_hire.country,
        manager: pending_hire.manager,
        userID: pending_hire.user_id,
        userGUID: pending_hire&.user&.guid
      }
    end

    def remove_unnecessary_params(params)
      params.delete(:format)
      params.delete(:controller)
      params.delete(:action)
      
      params
    end

    def prepare_pending_hire_data_hash(params)
      remove_unnecessary_params(params)

      pending_hire = @company.pending_hires.where(guid: params[:id]).take
      
      if pending_hire.present?
        log(params.to_hash, 200, 'OK', 'GET PendingHire')
        return { customer: {domain: @company.domain, companyID: @company.id}, pending_hire: prepare_hash(pending_hire), status: 200 }
      else
        log(params.to_hash, 400, 'Invalid PendingHire ID', 'GET PendingHire')
        return { message: 'Invalid PendingHire ID', status: 400 }
      end
    end

    def prepare_pending_hires_data_hash(params)
      remove_unnecessary_params(params)

      pending_hires = @company.pending_hires

      limit = (params[:limit].present? && params[:limit].to_i > 0) ? params[:limit].to_i : 50
      total_pages = (pending_hires.count/limit.to_f).ceil

      if params[:page].to_i < 0 || total_pages < params[:page].to_i
        log(params.to_hash, 400, 'Invalid Page Offset', 'GET PendingHires')
        return { message: 'Invalid Page Offset', status: 400 }
      end

      page = (pending_hires.count <= 0) ? 0 : (!params[:page].present? || params[:page].to_i == 0 ? 1 : params[:page].to_i)
      data = { current_page: page, total_pages: (pending_hires.count <= 0) ? 0 : ((total_pages == 0) ? 1 : total_pages), total_pending_hires: pending_hires.count, customer: {domain: @company.domain, companyID: @company.id}, pending_hires: [] }

      if page > 0
        paginated_pending_hires = pending_hires.paginate(:page => page, :per_page => limit)
        paginated_pending_hires.each do |pending_hire|
          data[:pending_hires].push prepare_hash(pending_hire)
        end
      end

      log(params.to_hash, 200, 'OK', 'GET PendingHires')
      data.merge!(status: 200)
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