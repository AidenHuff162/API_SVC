class HrisIntegrationsService::Workday::FetchWorkdayEmployeeInSapling < ApplicationService
  include HrisIntegrationsService::Workday::Logs
  attr_reader :worker_type, :recently_updated, :worker_id, :company, :include_image, :end_page, :action, :worker_subtype_filters,
              :fetch_all_departments

  delegate :workers_hash, :get_worker_subtype_filters, to: :helper_service
  delegate :prepare_request, :sync_workday, to: :web_service

  def initialize(kwargs)
    @company, @worker_type, @recently_updated = kwargs.values_at(:company, :worker_type, :recently_updated)
    @worker_id, @include_image, @fetch_all_departments = kwargs.values_at(:worker_id, :include_image, :fetch_all_departments)
    @start_page, @end_page, @action = kwargs.values_at(:start_page, :end_page, :fetch_action)
    @worker_subtype_filters = get_worker_subtype_filters(company, worker_type)
  end

  def call
    send(action)
  end

  private

  def fetch_workers
    response = nil
    loop do |_|
      begin
        response = get_workers_response(@start_page)
        return if (response_body = response&.body).blank?

        create_workers_in_bulk(workers_hash(response_body))
        sync_workday
      rescue Exception => @error
        error_log(fetch_worker_error_message, error_result_params(response&.body), error_api_params)
      end
      break if @start_page.blank? || ((@start_page += 1) > (end_page || 0))
    end
  end

  def fetch_workers_total_pages
    response_results = response_results_hash(get_workers_response(nil).body) rescue {}
    response_results[:total_pages].to_i
  end

  def get_workers_response(page)
    prepare_request('get_workers', get_workers_request_params(page))
  end

  def response_results_hash(data)
    data&.dig(:get_workers_response, :response_results)
  end

  def create_workers_in_bulk(workers)
    # workers = workers[0...3] rescue []
    workers.each { |worker| create_worker(worker) }
  end

  def create_worker(worker)
    return if worker.blank?

    response_success_log(worker)
    begin
      params = build_sapling_params(worker[:worker_data])
      user_params = params[:user]
      if fetch_all_departments &&
        (user = company.users.active.find_by(email: user_params[:email], workday_id: user_params[:workday_id])) &&
        (worker_subtype_filters.include?(user.workday_worker_subtype))

        HrisIntegrationsService::Workday::Update::DepartmentsInSapling.call(user, user_params[:team_id])
        return
      end

      return unless filters_applicable?(params)

      params[:user][:workday_id_type] = worker_type
      create_worker_in_sapling(params[:user], params[:custom_field])
    rescue Exception => @error
      msg = "Unable to create the worker with workday id: #{worker.dig(:worker_data, :worker_id)} in Sapling"
      error_log(msg, error_result_params, error_api_params)
    end
  end

  def response_success_log(worker)
    res = { response: worker[:worker_data] }
    msg = "Got the response for: [#{worker_type}:#{worker.dig(:worker_data, :worker_id)}#{", page#:#{@start_page}" if @start_page}]"
    success_log(msg, res)
  end

  def build_sapling_params(worker)
    HrisIntegrationsService::Workday::ParamsBuilder::Sapling.call(worker, company, helper_service)
  end

  def create_worker_in_sapling(user_params, custom_field_params)
    HrisIntegrationsService::Workday::Create::WorkdayInSapling.call(company, user_params, custom_field_params, helper_service)
  end

  def fetch_worker_error_message
    "Unable to fetch#{recently_updated ? ' recently updated ' : ' '}workers with #{worker_type} in Sapling"
  end

  def filters_applicable?(params)
    params.present? && IntegrationsService::Filters.call(get_filter_params(params), company.get_integration('workday')) &&
      worker_subtype_filters.include?(params[:user][:workday_worker_subtype])
  end

  def error_result_params(response={})
    {
      response: response
    }
  end

  def error_api_params
    {
      params: {
        worker_type: worker_type,
        recently_updated: recently_updated,
        worker_id: worker_id,
        company: company.id,
        include_image: include_image
      }
    }
  end

  def get_request_name
    worker_id ? 'fetch_worker' : "fetch#{get_recently_updated_request}_#{get_worker_type_request}"
  end

  def get_workers_request_params(page=nil)
    attrs = worker_id ? { worker_id: worker_id, worker_type: worker_type, fetch_all_departments: fetch_all_departments } : { page: page, fetch_all_departments: fetch_all_departments }
    HrisIntegrationsService::Workday::ParamsBuilder::Workday.call(get_request_name, attrs)
  end

  def get_recently_updated_request
    '_recently_updated' if recently_updated
  end

  def get_worker_type_request
    worker_type == 'Employee_ID' ? 'employee_workers' : 'contingent_workers'
  end

  def web_service
    HrisIntegrationsService::Workday::WebService.new(company.id)
  end

  def helper_service
    @helper_object ||= HrisIntegrationsService::Workday::Helper.new
  end

  def get_filter_params(params)
    {
      location_id: params[:user][:location_id],
      team_id: params[:user][:team_id],
      employee_type: params[:custom_field][:employment_status]&.titleize
    }
  end

end
