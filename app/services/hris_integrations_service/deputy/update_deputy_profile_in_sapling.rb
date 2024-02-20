class HrisIntegrationsService::Deputy::UpdateDeputyProfileInSapling
  attr_reader :company, :integration

  delegate :create_loggings, to: :helper_service

  def initialize(company, integration)
    @company = company
    @integration = integration

    @should_fetch_ids = fetch_sapling_users.present?
  end

  def update
    fetch_updates if @should_fetch_ids.present?
  end

  private

  def fetch_updates
    miss_matched_emails = []
    matched_emails = []
    begin
      response = HTTParty.get("https://#{integration.subdomain}/api/v1/supervise/employee",
        headers: { accept: 'application/json', content_type: 'application/json', authorization: "Bearer #{@integration.access_token}" }
      )

      deputy_users = JSON.parse(response.body) rescue nil
      
      deputy_users.try(:each) do |user|
        deputy_id = user['Id'] rescue nil
        next if deputy_id.blank? || (deputy_id.present? && @company.users.exists?(deputy_id: deputy_id))

        map_deputy_ids(user, miss_matched_emails, matched_emails)        
      end

      @integration.update_column(:unsync_records_count, fetch_sapling_users.count)

      create_loggings(@company, 'Deputy', 200, "Fetch deputy IDs - Mismatched emails", miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
      create_loggings(@company, 'Deputy', 200, "Fetch deputy IDs - Matched emails", matched_emails, 'fetch_users') if matched_emails.present?
    rescue Exception => e
      create_loggings(@company, 'Deputy', 500, "Update deputy user in sapling - Failure", {response: e.message}, 'fetching_users')
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end
  
  def map_deputy_ids(deputy_user, miss_matched_emails, matched_emails)
    begin
      emails = [deputy_user['Email'].try(:downcase)]

      emails.reject!(&:blank?)

      if emails.present?
        users = fetch_sapling_users.where('(email IN (?))', emails)
        if users.blank?
          miss_matched_emails.push({sapling: 'No match', deputy: {id: deputy_user['Id'], emails: emails}})
        else
          if users.count == 1
            matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, deputy: {id: deputy_user['Id'], emails: emails}})
            users.update_all(deputy_id: deputy_user['Id']&.to_i)
          else
            miss_matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, deputy: {id: deputy_user['Id'], emails: emails}})
          end
        end
      end  
    rescue Exception => e
      create_loggings(@company, 'Deputy', 500, "Map deputy ID code issue", {result: e.message})
    end
  end  

  def fetch_sapling_users
    company.users.where("state = 'active' AND current_stage != ? AND deputy_id IS NULL AND super_user = ?", User.current_stages[:incomplete], false)
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end