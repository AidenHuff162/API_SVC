class HrisIntegrations::Workday::UpdateWorkdayManagersInSapling
  require 'sidekiq-pro' unless Rails.env.test?
  include Sidekiq::Worker
  sidekiq_options queue: :receive_employee_from_workday, backtrace: true, retry: false
  JOB_LIMIT = 4

  def perform(company_id, fetch_all)
    return if (@company = Company.find_by_id(company_id)).blank?

    batch = Sidekiq::Batch.new
    batch.on(:complete, HrisIntegrations::Workday::UpdateWorkdayManagersInSapling, company_id: company_id)
    params = { company_id: company_id }
    %w[pending_hires users].each do |record_type|
      params[:record_type] = record_type
      record_id_groups = get_record_ids(record_type, fetch_all).in_groups(JOB_LIMIT, false).reject(&:blank?) rescue []
      record_id_groups.each do |record_ids|
        params[:record_ids] = record_ids
        batch.jobs { HrisIntegrations::Workday::SyncWorkdayManagersInSaplingJob.perform_async(params.dup) }
      end
    end
  end

  private

  def on_complete(status, options)
    Company.find_by_id(options['company_id']).run_create_organization_chart_job
  end


  def get_record_ids(record_type, fetch_all)
    @company.send(record_type).with_workday.where(fetch_all ? '' : "created_at >= '#{12.hours.ago}'").ids
  end

end
