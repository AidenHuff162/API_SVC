class HrisIntegrationsService::Workday::Update::ManagersInSapling < ApplicationService
  include HrisIntegrationsService::Workday::Logs

  attr_reader :company, :records, :records_type

  delegate :workers_hash, :convert_to_array, :get_manager_from_org, to: :helper_service
  delegate :prepare_request, to: :web_service

  def initialize(company, records)
    @company, @records, @records_type = company, records, records&.take.class.to_s
  end

  def call
    update_managers
  end

  private

  def update_managers
    filtered_users = IntegrationsService::Filters.call(records, company.get_integration('workday'))
    filtered_users.find_each { |obj| assign_manager(obj) }
  end

  def get_worker_data(response_body, type)
    convert_to_array(workers_hash(response_body).first[:worker_data].dig(*worker_data_dig_hash[type])) rescue []
  end

  def employment_organization_params(obj)
    params = { workday_id: obj.workday_id, workday_id_type: obj.workday_id_type }
    HrisIntegrationsService::Workday::ParamsBuilder::Workday.call('worker_employment_organization_data', params)
  end

  def get_employment_organization_response(obj)
    prepare_request('get_workers', employment_organization_params(obj))
  end

  def manager_dig_hash
    { job: %i[position_data manager_as_of_last_detected_manager_change_reference], org: %i[organization_type_reference id] }
  end

  def get_manager_id(obj, workday_manager_id)
    return if workday_manager_id.blank?

    obj.company.users.find_by(workday_id: workday_manager_id)&.id
  end

  def assign_manager(obj)
    begin
      response_body = get_employment_organization_response(obj).body
      return if (worker_job_data = get_worker_data(response_body, :job).first).blank?

      workday_manager_id = convert_to_array(worker_job_data.dig(*manager_dig_hash[:job])).first.dig(:id).second rescue nil
      workday_manager_id ||= get_manager_from_org(convert_to_array(get_worker_data(response_body, :org)))
      sapling_manager_id = get_manager_id(obj, workday_manager_id)
      update_params = { manager_id: sapling_manager_id, skip_org_chart_callback: (records_type == 'User' || nil) }.compact
      obj.update!(update_params) if sapling_manager_id
      update_manager_in_snapshot(obj) if records_type == 'User'
    rescue Exception => @error
      error_log("Unable to assign manager for #{obj.class} with id: (#{obj.id}) in Sapling",
                { response: worker_job_data })
    end
  end

  def helper_service
    @helper_object ||= HrisIntegrationsService::Workday::Helper.new
  end

  def web_service
    HrisIntegrationsService::Workday::WebService.new(company.id)
  end

  def worker_data_dig_hash
    { job: %i[employment_data worker_job_data], org: %i[organization_data worker_organization_data] }
  end

  def update_manager_in_snapshot(user)
    return unless company.is_using_custom_table?

    role_info = CustomTable.role_information(company.id)
    cs = role_info.custom_table_user_snapshots.find_by(state: 'applied', user_id: user.id)
                  .custom_snapshots.find_by(preference_field_id: 'man', custom_field_value: nil) rescue nil
    cs.update_column(:custom_field_value, user.manager_id.to_s) if cs.present? && user.manager_id?
  end

end
