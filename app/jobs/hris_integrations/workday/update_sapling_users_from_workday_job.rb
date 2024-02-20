class HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob
  require 'sidekiq-pro' unless Rails.env.test?
  include Sidekiq::Worker
  sidekiq_options queue: :receive_employee_from_workday, backtrace: true, retry: false, lock: :until_executed

  JOB_LIMIT = 4

  def perform(company_id, fetch_all=false, fetch_all_departments=false)
    return unless (company = Company.find_by_id(company_id))
    return fetch_all if Rails.env.test?

    batch = Sidekiq::Batch.new
    batch.on(:complete, HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob,
             company_id: company_id, fetch_all: fetch_all, fetch_all_departments: fetch_all_departments)
    batch.jobs { fetch_workday_workers(company, fetch_all, fetch_all_departments) }
    company.get_integration('workday').update_column(:sync_status, :in_progress) if batch.jids.count.positive?
  end

  def on_complete(status, options)
    return if options['fetch_all_departments']
    Company.find_by_id(options['company_id']).get_integration('workday').update_column(:sync_status, :succeed)
    HrisIntegrations::Workday::UpdateWorkdayManagersInSapling.perform_async(options['company_id'], options['fetch_all'])
    HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob.perform_async(options['company_id'], true, true) unless options['fetch_all']
  end

  private

  def get_total_pages(company, worker_type, fetch_all, fetch_all_departments)
    params = { fetch_action: 'fetch_workers_total_pages', company: company, worker_type: worker_type,
               recently_updated: !fetch_all, fetch_all_departments: fetch_all_departments }
    HrisIntegrationsService::Workday::FetchWorkdayEmployeeInSapling.call(params)
  end

  def page_numbers_hash(start_page, end_page, worker_type)
    { start_page: start_page, end_page: end_page, worker_type: worker_type }
  end

  def fetch_workday_workers(company, fetch_all, fetch_all_departments)
    params = { action: fetch_all ? 'fetch_all' : 'fetch_recently_updated', company_id: company.id,
               fetch_all_departments: fetch_all_departments }

    %w[Employee_ID Contingent_Worker_ID].each do |worker_type|
      next if (total_worker_pages = get_total_pages(company, worker_type, fetch_all, fetch_all_departments)).zero?

      if total_worker_pages > JOB_LIMIT
        params.merge!(page_numbers_hash(0, 0, worker_type))
        offset = total_worker_pages / JOB_LIMIT
        while params[:start_page] < (offset * JOB_LIMIT)
          params[:start_page] += 1; params[:end_page] += offset
          HrisIntegrations::Workday::FetchWorkdayWorkersJob.perform_async(params.dup)
          params[:start_page] = params[:end_page]
        end
        if total_worker_pages > params[:end_page]
          params[:start_page] += 1; params[:end_page] = total_worker_pages
          HrisIntegrations::Workday::FetchWorkdayWorkersJob.perform_async(params.dup)
        end
      else
        params.merge!(page_numbers_hash(1, total_worker_pages, worker_type))
        HrisIntegrations::Workday::FetchWorkdayWorkersJob.perform_async(params.dup)
      end
    end
  end

end
