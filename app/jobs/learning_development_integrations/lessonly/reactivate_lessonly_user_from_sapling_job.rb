class LearningDevelopmentIntegrations::Lessonly::ReactivateLessonlyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_learn_and_development_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    
    if user.present? && user.lessonly_id.present?
      ::LearningAndDevelopmentIntegrationServices::Lessonly::ManageSaplingProfileInLessonly.new(user).perform('reactivate')
    end
  end
end