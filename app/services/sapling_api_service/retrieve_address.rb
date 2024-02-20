module SaplingApiService
  class RetrieveAddress
    
    FILTERS = [ 'country_name', 'limit', 'page' ]
    
    def initialize(company, request, token)
      @company = company
      @request = request
      @token = token
    end

    def fetch_countries(params)
      prepare_countries_data_hash(params)
    end

    def fetch_states(params)
      prepare_states_data_hash(params)
    end

    private

    def prepare_hash(country)
      data = { 
        name: country.name,
        key: country.key
      }
    end

    def remove_unnecessary_params(params)
      params.delete(:format)
      params.delete(:controller)
      params.delete(:action)
      
      params
    end

    def is_invalid_filters?(params)
      remove_unnecessary_params(params)

      return !params.keys.to_set.subset?(FILTERS.to_set)
    end

    def prepare_states_data_hash(params)
      if is_invalid_filters?(params)
        return { message: I18n.t("api_notification.invalid_filters"), status: 422 }
      end

      country = Country.where("lower (name) = ?", params['country_name'].to_s.downcase).take
      return { message: I18n.t("api_notification.invalid_country_name"), status: 422 } unless country.present?
      
      states = country.states.order('name ASC')
      
      limit = (params[:limit].present? && params[:limit].to_i > 0) ? params[:limit].to_i : 50
      total_pages = (states.count/limit.to_f).ceil

      if params[:page].to_i < 0 || total_pages < params[:page].to_i
        log(params.to_hash, 400, 'Invalid Page Offset', 'GET States')
        return { message: 'Invalid Page Offset', status: 400 }
      end

      page = (states.count <= 0) ? 0 : (!params[:page].present? || params[:page].to_i == 0 ? 1 : params[:page].to_i)
      data = { current_page: page, total_pages: (states.count <= 0) ? 0 : ((total_pages == 0) ? 1 : total_pages), total_states_count: states.count, country: {name: country.name, key: country.key}, states: [] }

      if page > 0
        paginated_states = states.paginate(:page => page, :per_page => limit)
        paginated_states.each do |state|
          data[:states].push prepare_hash(state)
        end
      end

      log(params.to_hash, 200, 'OK', 'GET States')
      data.merge!(status: 200)
    end

    def prepare_countries_data_hash(params)
      remove_unnecessary_params(params)

      countries = Country.all.order('name ASC')

      limit = (params[:limit].present? && params[:limit].to_i > 0) ? params[:limit].to_i : 50
      total_pages = (countries.count/limit.to_f).ceil

      if params[:page].to_i < 0 || total_pages < params[:page].to_i
        log(params.to_hash, 400, 'Invalid Page Offset', 'GET Countries')
        return { message: 'Invalid Page Offset', status: 400 }
      end

      page = (countries.count <= 0) ? 0 : (!params[:page].present? || params[:page].to_i == 0 ? 1 : params[:page].to_i)
      data = { current_page: page, total_pages: (countries.count <= 0) ? 0 : ((total_pages == 0) ? 1 : total_pages), total_countries: countries.count, countries: [] }

      if page > 0
        paginated_countries = countries.paginate(:page => page, :per_page => limit)
        paginated_countries.each do |country|
          data[:countries].push prepare_hash(country)
        end
      end

      log(params.to_hash, 200, 'OK', 'GET Countries')
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
