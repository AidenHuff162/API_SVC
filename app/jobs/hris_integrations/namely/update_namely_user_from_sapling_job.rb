class HrisIntegrations::Namely::UpdateNamelyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_employee_to_hr, :retry => false, :backtrace => true

  def perform(args)
    user = User.find_by(id: args['user_id'])
    
    if user.present? && user.namely_id.present?
      ::HrisIntegrationsService::Namely::ManageSaplingProfileInNamely.new(user.company, user).perform('update', args['attributes'])
    end
  end
end