class LearningAndDevelopmentIntegrationServices::Lessonly::UpdateLessonlyProfileInSapling
  attr_reader :company, :integration

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :fetch_users, to: :endpoint_service, prefix: :execute 

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
    page = 1
    fetch_more = true
    miss_matched_emails = []
    matched_emails = []

    while fetch_more
      response = execute_fetch_users(@integration, page)
      break if [204, 200].exclude?(response.code)

      parsed_response = JSON.parse(response.body) rescue nil
      break if parsed_response.blank? 

      fetch_more = false if response.code == 204 || (response.code == 200 && parsed_response['users'].count < 50)
      page = page + 1

      parsed_response['users'].try(:each) do |user|
        lessonly_id = user['id'] rescue nil
        next if lessonly_id.blank? || (lessonly_id.present? && @company.users.exists?(lessonly_id: lessonly_id))

        map_lessonly_ids(user, miss_matched_emails, matched_emails)        
      end
    end

    @integration.update_column(:unsync_records_count, fetch_sapling_users.count)

    log(200, 'Fetch Lessonly IDs - Mismatched emails', miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
    log(200, 'Fetch Lessonly IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?
  end

  def map_lessonly_ids(lessonly_user, miss_matched_emails, matched_emails)
    begin
      emails = [lessonly_user['email'].try(:downcase)]

      emails.reject!(&:blank?)

      if emails.present?
        users = fetch_sapling_users.where('(personal_email IN (?) OR email IN (?))', emails, emails)
        if users.blank?
          miss_matched_emails.push({sapling: 'No match', lessonly: {id: lessonly_user['id'], emails: emails}})
        else
          if users.count == 1
            matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, lessonly: {id: lessonly_user['id'], emails: emails}})
            users.update_all(lessonly_id: lessonly_user['id'])
          else
            miss_matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, lessonly: {id: lessonly_user['id'], emails: emails}})
          end
        end
      end  
    rescue Exception => e
      log(500, 'Map Lessonly ID code issue', e.message)
    end
  end

  def fetch_sapling_users
    company.users.where("state = 'active' AND current_stage != ? AND lessonly_id IS NULL AND super_user = ?", User.current_stages[:incomplete], false)
  end

  def log(status, action, result, request = nil)
    create_loggings(@company, "Lessonly", status, action, result, request)
    log_statistics((status == 200 ? 'success' : 'failure'), @company)
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Lessonly::Helper.new
  end

  def endpoint_service
    LearningAndDevelopmentIntegrationServices::Lessonly::Endpoint.new
  end
end