module AtsIntegrations
  class Workable

    def initialize(company, workable_api = nil)
      @company = company
      @workable_api = workable_api
    end

    def subscribe
      data = {
        target: "https://#{@company.domain}/api/v1/admin/webhook_integrations/workable#create",
        event: "candidate_moved",
        args: {
          account_id: @workable_api.subdomain,
          job_shortcode: "",
          stage_slug: "hired"
        }
      }

      response = HTTParty.post("https://#{@workable_api.subdomain}.workable.com/spi/v3/subscriptions",
        body: data.to_json,
        headers: {'Accept' => "application/json", 'Content-Type' => "application/json", 'X-WORKABLE-CLIENT-ID' => ENV['WORKABLE_X_CLIENT_ID'], 'Authorization' => "Bearer #{@workable_api.access_token}" }
      )

      puts "Subscribe: #{response.inspect}, Body: #{response.body}"

      create_loggings('Endpoint Subscription', { result: response.inspect, id: JSON.parse(response.body)['id'] }, 'Workable', data, 200)
      @workable_api.subscription_id(JSON.parse(response.body)['id']) if JSON.parse(response.body)['id'].present?
      @company.update(is_recruitment_system_integrated: true)

      JSON.parse(response.body)['id']
    end

    def unsubscribe
      response = HTTParty.delete("https://#{@workable_api.subdomain}.workable.com/spi/v3/subscriptions/#{@workable_api.subscription_id}",
        headers: {'Accept' => "application/json", 'Content-Type' => "application/json", 'X-WORKABLE-CLIENT-ID' => ENV['WORKABLE_X_CLIENT_ID'], 'Authorization' => "Bearer #{@workable_api.access_token}" }
      )

      puts "UnSubscribe: #{response.inspect}, Body: #{response.body}"

      create_loggings('Endpoint Un-Subscription', { result: response.inspect, id: JSON.parse(response.body) }, 'Workable', { id: @workable_api.subscription_id }, 200)
      if !JSON.parse(response.body)['error'].present?
        @workable_api.integration_credentials.find_by(name: "Subscription Id").update(value: nil)
        @company.update(is_recruitment_system_integrated: false) if @company.pending_hires.count > 0
      end
    end

    def create(data)
      pending_hire_data = {}
      pending_hire_data[:first_name] = data[:data][:firstname] rescue nil
      pending_hire_data[:last_name] = data[:data][:lastname] rescue nil
      pending_hire_data[:title] = data[:data][:job][:title] rescue nil
      pending_hire_data[:start_date] = data[:fired_at] rescue nil
      pending_hire_data[:phone_number] = data[:data][:phone] rescue nil
      pending_hire_data[:personal_email] = data[:data][:email] rescue nil
      job = job_details(data['data']['job']['shortcode'])
      if(@company.subdomain == 'camelotillinois')
        pending_hire_data[:employee_type] = job['employment_type'] rescue nil
      else
        pending_hire_data[:employee_type] = job['employment_type'].parameterize.underscore rescue nil
      end
      pending_hire_data[:department] = job['department'] rescue nil

      city = job['location']['city'] rescue nil
      country = job['location']['country'] rescue nil

      if city.present? && country.present?
        pending_hire_data[:location] = "#{city.try(:strip)}, #{country.try(:strip)}"
      elsif city.present?
        pending_hire_data[:location] = city.try(:strip)
      end

      PendingHire.create_by_workable(pending_hire_data, @company)
    end

    private
    
    def create_loggings(action, response, integration_name, api_request, status)
      LoggingService::IntegrationLogging.new.create(@company, integration_name, action, api_request, {response: response}, status)
    end

    def job_details(shortcode)
      response = HTTParty.get("https://#{@workable_api.subdomain}.workable.com/spi/v3/jobs/#{shortcode}",
        headers: {'Accept' => "application/json", 'Content-Type' => "application/json", 'X-WORKABLE-CLIENT-ID' => ENV['WORKABLE_X_CLIENT_ID'], 'Authorization' => "Bearer #{@workable_api.access_token}" }
      )

      JSON.parse(response.body) rescue {}
    end
  end
end
