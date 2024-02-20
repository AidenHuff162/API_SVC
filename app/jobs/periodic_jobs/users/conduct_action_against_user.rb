module PeriodicJobs::Users
  class ConductActionAgainstUsers
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::ConductActionAgainstUsers').ping_start
      
      User.with_deleted.where('is_gdpr_action_taken = ? AND current_stage = ? AND gdpr_action_date IS NOT NULL AND gdpr_action_date <= ?',
        false, User.current_stages[:departed], Date.today).try(:each) { |user| ::GeneralDataProtectionRegulation::ConductActionAgainstUserJob.perform_later(user.id) }
      
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::ConductActionAgainstUsers').ping_ok
    end
  end
end
