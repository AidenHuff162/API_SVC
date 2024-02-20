class HrisIntegrations::Deputy::UpdateDeputyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(args)
    user = User.find_by(id: args['user_id'])

    if user.present? && user.deputy_id.present? && args['attributes'].present?
      ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform('update', args['attributes'])
    end
  end
end