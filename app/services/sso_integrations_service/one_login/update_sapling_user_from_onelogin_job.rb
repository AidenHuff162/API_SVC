class SsoIntegrationsService::OneLogin::UpdateSaplingUserFromOneloginJob
  attr_reader :company, :integration

  delegate :fetch, :log, to: :helper_service

  def initialize(company)
    @company = company
    @should_fetch_ids = fetch_sapling_users.present?
  end

  def update
    fetch_updates if @should_fetch_ids.present?
  end

  private

  def fetch_updates
    startIndex = nil
    fetch_more = true
    miss_matched_emails = []
    matched_emails = []

    while fetch_more
      response = fetch(startIndex)

      parsed_response = JSON.parse(response.body) rescue nil
      break if parsed_response.blank? 

      fetch_more = false if response.code == '200' && parsed_response['pagination'].present? && parsed_response['pagination']['after_cursor'] == nil
      startIndex = parsed_response['pagination']['after_cursor']

      parsed_response['data'].try(:each) do |resource|
        one_login_id = resource['id'] rescue nil
        next if one_login_id.blank? || (one_login_id.present? && @company.users.exists?(one_login_id: one_login_id))

        map_one_login_ids(resource, miss_matched_emails, matched_emails)        
      end
    end

    log(200, 'Fetch OneLogin IDs - Mismatched emails', miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
    log(200, 'Fetch OneLogin IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?
  end

  def map_one_login_ids(resource, miss_matched_emails, matched_emails)
    begin
      emails = resource['email']

      if emails.present?
        users = fetch_sapling_users.where('(email IN (?))', emails)
        if users.blank?
          miss_matched_emails.push({sapling: 'No match', OneLogin: {id: resource['id'], emails: emails}})
        else
          if users.count == 1
            matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, OneLogin: {id: resource['id'], emails: emails}})
            users.update_all(one_login_id: resource['id'])
          else
            miss_matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, OneLogin: {id: resource['id'], emails: emails}})
          end
        end
      end  
    rescue Exception => e
      log(500, 'Map OneLogin ID code issue', e.message)
    end
  end

  def fetch_sapling_users
    company.users.where('current_stage != ? AND one_login_id IS NULL AND super_user = ?', User.current_stages[:incomplete], false)
  end

  def helper_service
    ::SsoIntegrationsService::OneLogin::User.new company
  end
end
