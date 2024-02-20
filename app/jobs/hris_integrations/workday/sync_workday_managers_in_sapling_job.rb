class HrisIntegrations::Workday::SyncWorkdayManagersInSaplingJob
  include Sidekiq::Worker
  sidekiq_options queue: :receive_employee_from_workday, backtrace: true, retry: false

  def perform(kwargs)
    kwargs.transform_keys!(&:to_sym) if kwargs.is_a?(Hash)
    return if kwargs.blank? || (company = Company.find_by_id(kwargs[:company_id])).blank?

    params = { action: 'sync_managers', records: company.send(kwargs[:record_type]).where(id: kwargs[:record_ids]) }
    HrisIntegrationsService::Workday::ManageWorkdayInSapling.new(company).perform(params)
    # puts "MANAGER SYNC #{params}"
  end
end
