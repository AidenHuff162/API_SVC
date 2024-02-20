class CreateJobTierAndTitleInNamelyJob < ApplicationJob
  queue_as :receive_employee_from_hr

  def perform(namely_api, title, tier, company_id)
    secret_token = namely_api.permanent_access_token rescue nil
    subdomain = namely_api.company_url rescue nil

    if secret_token.present? && subdomain.present?
      tier_id = nil
      if tier.present?
        tier_data = { "job_tiers": [{"title": tier}] }
        begin
          namely = Namely::Connection.new(
            access_token: secret_token,
            subdomain: subdomain
          )
          tier_id = namely.job_tiers.all.select { |job_tier| job_tier.title.downcase.eql?(tier.downcase) }.first.id rescue nil

          if !tier_id.present?
            tier_response = HTTParty.post("https://#{subdomain}.namely.com/api/v1/job_tiers",
              body: tier_data,
              headers: { accept: "application/json", authorization: "Bearer #{secret_token}" }
            )
            tier_id = JSON.parse(tier_response.body)['job_tiers'][0]['id']
            
            create_integration_logging(namely_api.company, {namely_new_tier:  tier_data.inspect}, {namely_tier: JSON.parse(tier_response.body)}, 200)
          end
        rescue Exception => exception
          puts "Create Job Tier in Namely Job: #{exception}"
          create_integration_logging(namely_api.company, {namely_new_tier:  tier_data.inspect}, {error: exception.message}, 500)
        end
      end

      if tier_id.present? && title.present?
        title_data = { "job_titles": [{"title": title, "parent": tier_id}] }

        begin
          title_exist = namely.job_titles.all.select { |job_title| job_title.title.downcase.eql?(title.downcase) && job_title.parent_id == tier_id }.present?
          if title_exist == false
            title_response = HTTParty.post("https://#{subdomain}.namely.com/api/v1/job_titles",
              body: title_data,
              headers: { accept: "application/json", authorization: "Bearer #{secret_token}" }
            )
            
            create_integration_logging(namely_api.company, {namely_new_title: title_data.inspect}, {namely_title: JSON.parse(title_response.body)}, 200)
          end
        rescue Exception => exception
          puts "Create Job Title in Namely Job: #{exception}"
          create_integration_logging(namely_api.company, {namely_new_title: title_data.inspect}, {error: exception.message}, 500)
        end
      end
    end
  end

  def create_integration_logging(company, request, response, status)
    LoggingService::IntegrationLogging.new.create(company, 'NamelyHR', 'Create Job title', request, response, status) if company.present?
  end
end
