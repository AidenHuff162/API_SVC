class LearningDevelopmentIntegrations::LearnUpon::DeactivateLearnUponUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_learn_and_development_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    
    if user.present? && user.learn_upon_id.present?
      ::LearningAndDevelopmentIntegrationServices::LearnUpon::ManageSaplingProfileInLearnUpon.new(user).perform('deactivate')
    end
  end
end