class LearningAndDevelopmentIntegrationServices::Kallidus::UpdateKallidusProfileInSapling
  attr_reader :company, :integration, :user_id

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :fetch_users, to: :endpoint_service, prefix: :execute 

  def initialize(company, integration, user_id)
    @company = company
    @integration = integration
    @user_id = user_id
    @should_fetch_ids = fetch_sapling_users.present?
  end

  def update
    if @user_id.present?
      user = User.find_by(guid: @user_id)
      fetch_update(user)
    else
      fetch_updates if @should_fetch_ids.present?
    end
  end

  private

  def fetch_update(user)
    miss_matched_emails = []
    matched_emails = []

    endpoint = "?$filter=ImportKey%20eq%20'#{@user_id}'"
    response = execute_fetch_users(integration, endpoint)
    if response.ok?
      kallidus_user = JSON.parse(response.body)&.first

      map_kallidus_learn_id(user, kallidus_user, matched_emails, miss_matched_emails)

      log(200, 'Fetch KallidusLearn IDs - Mismatched emails', miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
      log(200, 'Fetch KallidusLearn IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?
      @integration.update_column(:unsync_records_count, fetch_sapling_users.count)
    else
      create_loggings(@company, 'KallidusLearn', response.code, "KallidusLearn Service Unavailable - Update from KallidusLearn")
    end
  end

  def fetch_updates
    miss_matched_emails = []
    matched_emails = []

    users = fetch_sapling_users
    users.try(:each) do |user|
      if user.email.present?
        endpoint = "?$filter=Email%20eq%20'#{user.email}'"
        response = execute_fetch_users(integration, endpoint)
        
        if response.ok?
          kallidus_user = JSON.parse(response.body)&.first
          map_kallidus_learn_id(user, kallidus_user, matched_emails, miss_matched_emails)
        else
          create_loggings(@company, 'KallidusLearn', response.code, "KallidusLearn Service Unavailable - Update from KallidusLearn")
        end
      end
    end

    log(200, 'Fetch KallidusLearn IDs - Mismatched emails', miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
    log(200, 'Fetch KallidusLearn IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?

    @integration.update_column(:unsync_records_count, fetch_sapling_users.count)
  end

  def map_kallidus_learn_id(user, kallidus_user, matched_emails, miss_matched_emails)
    begin
      if kallidus_user.present? 
        if kallidus_user['Id'].present?
          user.update(kallidus_learn_id: kallidus_user['Id'])
          matched_emails.push({sapling: {user: [user.id, user.email]}, kallidus_learn_user: {id: kallidus_user['Id'], emails: kallidus_user['EmailAddress']}})
        else
          miss_matched_emails.push({sapling: {user: [user.id, user.email]}, kallidus_learn_user: {id: kallidus_user['Id'], emails: kallidus_user['EmailAddress']}})
        end
      else
        miss_matched_emails.push({sapling: {user: [user.id, user.email]}, kallidus_learn: 'No Match'})
      end
    rescue Exception => e
      log(500, 'Map KallidusLearn ID code issue', e.message)
    end
  end

  def fetch_sapling_users
    company.users.where('current_stage != ? AND kallidus_learn_id IS NULL AND super_user = ?', User.current_stages[:incomplete], false)
  end

  def log(status, action, result, request = nil)
    create_loggings(@company, "KallidusLearn", status, action, result, request)
    log_statistics((status == 200 ? 'success' : 'failure'), @company)
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Kallidus::Helper.new
  end

  def endpoint_service
    LearningAndDevelopmentIntegrationServices::Kallidus::Endpoint.new
  end
end
