namespace :generate_asana_webhooks do

  task :generate_asana_webhooks => :environment do |t, args|
    url = URI::encode("https://app.asana.com/api/1.0/webhooks")
    TaskUserConnection.where(state: "in_progress", asana_webhook_gid: nil).where.not(asana_id: nil).find_each do |tuc|
      next unless tuc.owner.present?
      company = tuc.owner.company
      integration = company.integration_instances.find_by(api_identifier: "asana", state: :active)
      next unless integration.present?
      if Rails.env != "development"
        webhook_url = "https://#{company.domain}/api/v1/asana"
      else
        webhook_url = "https://#{company.subdomain}.ngrok.io/api/v1/asana"
      end
      webhook_data = { data: {
        resource: tuc.asana_id,
        target: webhook_url
      }}
      url = URI(URI::encode("https://app.asana.com/api/1.0/webhooks"))
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(url)
      request.body = JSON.dump(webhook_data)
      request["Asana-Enable"] = "new_rich_text"
      request["Accept"] = "application/json"
      request["content-type"] = "application/json"
      request["Authorization"] = "Bearer #{integration.asana_personal_token}"
      response = http.request(request)
      created_webhook = JSON.parse(response.read_body)
      if created_webhook["data"] && created_webhook["data"]["gid"]
        tuc.update!(asana_webhook_gid: created_webhook["data"]["gid"])
      end
      created_webhook
    end
  end

end
