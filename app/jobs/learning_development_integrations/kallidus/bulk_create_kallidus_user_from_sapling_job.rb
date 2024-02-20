class LearningDevelopmentIntegrations::Kallidus::BulkCreateKallidusUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_learn_and_development_integration_creation, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by(id: company_id)

    return unless company.integration_instances.find_by(api_identifier: "kallidus_learn").present?
    
    company.users.where(super_user: false).where.not(current_stage: :incomplete).find_each do |user|
      ::LearningAndDevelopmentIntegrationServices::Kallidus::ManageSaplingProfileInKallidus.new(user).perform('create')
    end

  end
end
