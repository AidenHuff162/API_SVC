class PerformanceManagementIntegrationsService::Peakon::UpdatePeakonProfileInSapling
  attr_reader :company, :integration

  delegate :create_loggings, :log_statistics, to: :helper_service

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
    startIndex = 1
    fetch_more = true
    miss_matched_emails = []
    matched_emails = []

    while fetch_more
      response = fetch_peakon_users(startIndex)
      break if [204, 200].exclude?(response.code)

      parsed_response = JSON.parse(response.body) rescue nil
      break if parsed_response.blank? 

      fetch_more = false if response.code == 204 || (response.code == 200 && parsed_response['Resources'].count < 100)
      startIndex = startIndex + 100

      parsed_response['Resources'].try(:each) do |resource|
        peakon_id = resource['id'] rescue nil
        next if peakon_id.blank? || (peakon_id.present? && @company.users.exists?(peakon_id: peakon_id))

        map_peakon_ids(resource, miss_matched_emails, matched_emails)        
      end
    end

    @integration.update_column(:unsync_records_count, fetch_sapling_users.count)

    log(200, 'Fetch Peakon IDs - Mismatched emails', miss_matched_emails, 'fetch_users') if miss_matched_emails.present?
    log(200, 'Fetch Peakon IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?
  end

  def fetch_peakon_users(startIndex = 1)
    HTTParty.get("https://api.peakon.com/scim/v2/Users?startIndex=#{startIndex}&count=100",
      headers: { accept: 'application/scim+json', authorization: "Bearer #{integration.access_token}" }
    )
  end

  def map_peakon_ids(resource, miss_matched_emails, matched_emails)
    begin
      emails = []

      resource['emails'].try(:each) { |email| emails.push(email['value']&.downcase) }
      emails.reject!(&:blank?)

      if emails.present?
        users = fetch_sapling_users.where('(personal_email IN (?) OR email IN (?))', emails, emails)
        if users.blank?
          miss_matched_emails.push({sapling: 'No match', peakon: {id: resource['id'], emails: emails}})
        else
          if users.count == 1
            matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, peakon: {id: resource['id'], emails: emails}})
            users.update_all(peakon_id: resource['id'])
          else
            miss_matched_emails.push({sapling: {user: users.pluck(:id, :email, :personal_email)}, fifteen_five: {id: resource['id'], emails: emails}})
          end
        end
      end  
    rescue Exception => e
      log(500, 'Map Peakon ID code issue', e.message)
    end
  end

  def fetch_sapling_users
    company.users.where('current_stage != ? AND peakon_id IS NULL AND super_user = ?', User.current_stages[:incomplete], false)
  end

  def log(status, action, result, request = nil)
    create_loggings(@company, "Peakon", status, action, result, request)
    log_statistics((status == 200 ? 'success' : 'failure'), @company)
  end

  def helper_service
    PerformanceManagementIntegrationsService::Peakon::Helper.new
  end
end
