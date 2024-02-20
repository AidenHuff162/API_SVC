class LearningAndDevelopmentIntegrationServices::LearnUpon::UpdateLearnUponProfileInSapling
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
    miss_matched_emails = []
    matched_emails = []

    response = execute_fetch_users(integration)
    parsed_response = JSON.parse(response.body)

    users = parsed_response['user'] rescue nil
    
    users.try(:each) do |user|
      learn_upon_id = user['id'] rescue nil
      next if learn_upon_id.blank? || (learn_upon_id.present? && @company.users.exists?(learn_upon_id: learn_upon_id))
      
      map_learn_upon_ids(user, miss_matched_emails, matched_emails)
    end

    @integration.update_column(:unsync_records_count, fetch_sapling_users.count)

    log(200, 'Fetch LearnUpon IDs - Mismatched emails', miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
    log(200, 'Fetch LearnUpon IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?
  end

  def map_learn_upon_ids(learn_upon_user, miss_matched_emails, matched_emails)
    begin
      emails = [learn_upon_user['email']]

      emails.reject!(&:blank?)

      if emails.present?
        users = fetch_sapling_users.where('(personal_email IN (?) OR email IN (?))', emails, emails)
        if users.blank?
          miss_matched_emails.push({sapling: 'No match', learn_upon: {id: learn_upon_user['id'], emails: emails}})
        else
          if users.count == 1
            matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, learn_upon: {id: learn_upon_user['id'], emails: emails}})
            users.update_all(learn_upon_id: learn_upon_user['id'])
          else
            miss_matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, learn_upon: {id: learn_upon_user['id'], emails: emails}})
          end
        end
      end  
    rescue Exception => e
      log(500, 'Map LearnUpon ID code issue', e.message)
    end
  end

  def fetch_sapling_users
    company.users.where('current_stage != ? AND learn_upon_id IS NULL AND super_user = ?', User.current_stages[:incomplete], false)
  end

  def log(status, action, result, request = nil)
    create_loggings(@company, "LearnUpon", status, action, result, request)
    log_statistics((status == 200 ? 'success' : 'failure'), @company)
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::LearnUpon::Helper.new
  end

  def endpoint_service
    LearningAndDevelopmentIntegrationServices::LearnUpon::Endpoint.new
  end
end