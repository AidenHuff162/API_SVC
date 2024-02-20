class LearningDevelopmentIntegrations::Kallidus::UpdateSaplingUserFromKallidusJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_learn_and_development_integration, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by(id: company_id)
    
    if company.present?
      ::LearningAndDevelopmentIntegrationServices::Kallidus::ManageKallidusProfileInSapling.new(company).perform
    end
  end
end
