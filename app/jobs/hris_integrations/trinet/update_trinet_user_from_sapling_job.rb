class HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_employee_to_hr, :retry => false, :backtrace => true

  def perform(args)
    user = User.find_by(id: args['user_id'])
    if user.present? && user.trinet_id.present? && args['attributes'].present?
      ::HrisIntegrationsService::Trinet::ManageSaplingProfileInTrinet.new(user).perform('update', args['attributes'])
    end
  end
end