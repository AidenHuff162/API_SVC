class LearningDevelopmentIntegrations::Lessonly::CreateLessonlyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_learn_and_development_integration_creation, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    
    if user.present? && user.lessonly_id.blank?
      ::LearningAndDevelopmentIntegrationServices::Lessonly::ManageSaplingProfileInLessonly.new(user).perform('create')
    end
  end
end