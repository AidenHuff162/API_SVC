class PerformanceIntegrations::Lattice::UpdateLatticeUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(args)
    user = User.find_by(id: args['user_id'])

    if user.present? && user.lattice_id.present?
      ::PerformanceManagementIntegrationsService::Lattice::ManageSaplingProfileInLattice.new(user.reload).perform('update')
    end
  end
end