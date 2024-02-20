module TeamSpirit
  class UpdateSaplingUserToTeamSpiritJob
    include Sidekiq::Worker
    sidekiq_options queue: :manage_team_spirit_integration

    def perform(instance_id)
      instance = IntegrationInstance.find_by(id: instance_id)
      return if instance.blank?
      TeamSpiritService::Main.new(instance).perform
    end
  end
end
