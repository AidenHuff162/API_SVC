class HrisIntegrationsService::Workday::ManageWorkdayInSapling
  include HrisIntegrationsService::Workday::Exceptions
  include HrisIntegrationsService::Workday::Logs

  attr_reader :company, :worker_type, :worker_id, :integration

  def initialize(company, worker_type=nil, worker_id=nil)
    @company, @worker_type, @worker_id = company, worker_type, worker_id
    @integration = company.get_integration('workday')
  end

  def perform(kwargs)
    return if integration.blank?
    begin
      validate_creds_presence!(integration)
      kwargs.merge!(company: company, fetch_action: get_fetch_action(kwargs[:action]))
      case kwargs[:action]
      when 'fetch_all', 'fetch_recently_updated'
        kwargs.merge!(recently_updated: kwargs[:action] == 'fetch_recently_updated',
                           start_page: kwargs[:start_page], end_page: kwargs[:end_page])
        HrisIntegrationsService::Workday::FetchWorkdayEmployeeInSapling.call(kwargs)
        (kwargs[:action] == 'fetch_all') && update_unsync_users_count
      when 'fetch_notified'
        return unless worker_type && worker_id

        kwargs.merge!(worker_type: worker_type, worker_id: worker_id, include_image: false)
        HrisIntegrationsService::Workday::FetchWorkdayEmployeeInSapling.call(kwargs)
      when 'sync_managers'
        HrisIntegrationsService::Workday::Update::ManagersInSapling.call(company, kwargs[:records])
      end
    rescue Exception => @error
      error_log('Unable to sync from Workday to Sapling')
    end
  end

  private

  def update_unsync_users_count
    integration.update_column(:unsync_records_count, integration.unsync_users.size)
  end

  def get_fetch_action(action)
    ['fetch_notified', 'fetch_all', 'fetch_recently_updated'].include?(action) ? 'fetch_workers' : 'fetch_total_pages'
  end

end
