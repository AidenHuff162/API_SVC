class PerformanceIntegrations::Lattice::CreateLatticeUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)

    if user.present? && user.lattice_id.blank?
      ::PerformanceManagementIntegrationsService::Lattice::ManageSaplingProfileInLattice.new(user).perform('create')
    end
  end
end