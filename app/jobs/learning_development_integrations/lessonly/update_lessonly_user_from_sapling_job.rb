class LearningDevelopmentIntegrations::Lessonly::UpdateLessonlyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_learn_and_development_integration, :retry => false, :backtrace => true

  def perform(args)
    return unless args['attributes'].present?
    user = User.find_by(id: args['user_id'])
    
    if user.present? && user.lessonly_id.present?
      ::LearningAndDevelopmentIntegrationServices::Lessonly::ManageSaplingProfileInLessonly.new(user).perform('update', args['attributes'])
    end
  end
end