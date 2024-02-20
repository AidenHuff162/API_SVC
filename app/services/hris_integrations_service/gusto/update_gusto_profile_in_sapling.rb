class HrisIntegrationsService::Gusto::UpdateGustoProfileInSapling
  attr_reader :company

  delegate :create_loggings, :log_statistics, :can_integrate_profile?, to: :helper_service
  delegate :fetch_users, :get_gusto_company, to: :endpoint_service, prefix: :execute 

  def initialize(company)
    @company = company
    @should_fetch_ids = fetch_sapling_users.present?
  end

  def update
    fetch_updates if @should_fetch_ids.present?
  end

  private

  def fetch_updates
    integrations = company.integration_instances.where("integration_instances.api_identifier = 'gusto' AND integration_instances.state = 1")
    integrations.find_each do |integration|
      page = 1
      fetch_more = true
      miss_matched_emails = []
      matched_emails = []
      begin
        response = execute_fetch_users(integration)

        parsed_response = JSON.parse(response.body) rescue nil
        return if parsed_response.blank? 

        parsed_response.try(:each) do |user|
          gusto_id = user['id'] rescue nil
          next if gusto_id.blank? || (gusto_id.present? && @company.users.exists?(gusto_id: gusto_id))

          map_gusto_ids(user, miss_matched_emails, matched_emails, integration)        
        end

        integration.update_column(:unsync_records_count, fetch_sapling_users.count)

        log(200, 'Fetch Gusto IDs - Mismatched emails', miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
        log(200, 'Fetch Gusto IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?
      rescue Exception => e
        log(500, "Update user in Sapling - Failure", {result: e.message}, 'fetch_users')
      end
    end 
  end

  def map_gusto_ids(gusto_user, miss_matched_emails, matched_emails, integration)
    begin
      emails = [gusto_user['email']]

      emails.reject!(&:blank?)

      if emails.present?
        users = fetch_sapling_users.where('(personal_email IN (?) OR email IN (?))', emails, emails)
        if users.blank?
          miss_matched_emails.push({sapling: 'No match', gusto: {id: gusto_user['id'], emails: emails}})
        else
          if users.count == 1 && can_integrate_profile?(integration, users[0])
            matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, gusto: {id: gusto_user['id'], emails: emails}})
            users.update_all(gusto_id: gusto_user['id'])
          else
            miss_matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, gusto: {id: gusto_user['id'], emails: emails}})
          end
        end
      end  
    rescue Exception => e
      log(500, 'Map Gusto ID code issue', e.message)
    end
  end

  def fetch_sapling_users
    company.users.where('current_stage != ? AND gusto_id IS NULL AND super_user = ?', User.current_stages[:incomplete], false)
  end

  def log(status, action, result, request = nil)
    create_loggings(@company, "Gusto", status, action, result, request)
    log_statistics((status == 200 ? 'success' : 'failure'), @company)
  end

  def helper_service
    ::HrisIntegrationsService::Gusto::Helper.new
  end

  def endpoint_service
    ::HrisIntegrationsService::Gusto::Endpoint.new
  end
end