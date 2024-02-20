class HrisIntegrationsService::Namely::Endpoint

  def fetch_profiles(credentials, page)
    get(credentials, "https://#{credentials.company_url}.namely.com/api/v1/profiles?page=#{page}&per_page=50")
  end

  def fetch_groups(credentials)
    get(credentials, "https://#{credentials.company_url}.namely.com/api/v1/groups")
  end

  def update_profile(credentials, data, user)
    put(credentials, "https://#{credentials.company_url}.namely.com/api/v1/profiles/#{user.namely_id}", data)
  end

  def get_profile_image(credentials, company, user_id)
    image = nil
    begin
      file = File.open("#{Rails.root}/tmp/profile_image/#{company.id}/profile-#{user_id}.jpg")
      body = { file: file }
      post(credentials, "https://#{credentials.company_url}.namely.com/api/v1/files", body, true)
    rescue Exception => e
      puts e.message
    ensure
      if file.present?
        file.close
        File.delete(file)
      end
    end
  end

  private

  def post(credentials, endpoint, data = {}, is_image = false)
    headers = { accept: "application/json", authorization: "Bearer #{credentials.permanent_access_token}" }
    headers.merge!(content_type: "multipart/form-data") if is_image
    HTTParty.post(endpoint,
    body: data,
    headers: headers)
  end

  def put(credentials, endpoint, data = {})
    HTTParty.put(endpoint,
    body: data,
    headers: { accept: "application/json", authorization: "Bearer #{credentials.permanent_access_token}" })
  end

  def get(credentials, endpoint)
    HTTParty.get(endpoint, headers: { accept: "application/json", authorization: "Bearer #{credentials.permanent_access_token}" })
  end
end