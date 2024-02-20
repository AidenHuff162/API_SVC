class LearningDevelopmentIntegrations::Kallidus::DeactivateKallidusUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_learn_and_development_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    
    if user.present? && !user.super_user
      ::LearningAndDevelopmentIntegrationServices::Kallidus::ManageSaplingProfileInKallidus.new(user).perform('deactivate')
    end
  end
end
