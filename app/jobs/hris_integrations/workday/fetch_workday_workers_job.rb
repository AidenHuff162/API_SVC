class HrisIntegrations::Workday::FetchWorkdayWorkersJob
  include Sidekiq::Worker
  sidekiq_options queue: :receive_employee_from_workday, backtrace: true, retry: false, lock: :until_executed

  def perform(kwargs)
    kwargs.transform_keys!(&:to_sym) if kwargs.is_a?(Hash)
    return if kwargs.blank? || (company = Company.find_by_id(kwargs[:company_id])).blank?

    HrisIntegrationsService::Workday::ManageWorkdayInSapling.new(company).perform(kwargs)
    # puts "FETCH WITH: #{kwargs}"
  end

end
