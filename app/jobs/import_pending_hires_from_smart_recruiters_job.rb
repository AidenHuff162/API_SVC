class ImportPendingHiresFromSmartRecruitersJob < ApplicationJob
  queue_as :pending_hires

  def perform(company_id)
    company = Company.find_by(id: company_id)
    if company.present?
      smart_recruiters_api = company.integration_instances.find_by_api_identifier("smart_recruiters")
      if validate_smartrecruiters_integration(smart_recruiters_api)
        smart_recruiters = AtsIntegrations::SmartRecruiters.new(company, smart_recruiters_api)
        smart_recruiters.import()
      end
    end
  end

  def validate_smartrecruiters_integration smart_recruiters_api
    smart_recruiters_api.present? && smart_recruiters_api.client_secret.present? && smart_recruiters_api.client_id.present? && smart_recruiters_api.access_token.present? && smart_recruiters_api.expires_in.present? && smart_recruiters_api.refresh_token.present?
  end
end

