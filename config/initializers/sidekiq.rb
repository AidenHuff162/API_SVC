require 'sidekiq-unique-jobs'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['SIDEKIQ_REDIS_URL'], network_timeout: 5, pool_timeout: 5 }
  Sidekiq::Status.configure_server_middleware config, expiration: 1.day
  Sidekiq::Status.configure_client_middleware config, expiration: 1.day

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  if ['production', 'staging', 'demo'].include?(Rails.env)
    config.periodic do |mgr|
      mgr.register('55 23 28-31 * *', 'PeriodicJobs::AddMonthlyActiveUsers', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 1 * * *', 'PeriodicJobs::Documents::RemoveExpiredUploadedFiles', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 2 * * *', 'PeriodicJobs::Users::RemoveExpiredGhostUsers', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 3 * * *', 'PeriodicJobs::PaperTrail::RemoveOldVersion', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 4 * * *', 'PeriodicJobs::FixCounters', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 4 * * *', 'PeriodicJobs::Users::ConductActionAgainstUsers', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)

      mgr.register('0 1 * * *', 'PeriodicJobs::Users::CreateUserCalendarEvent', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('*/30 * * * *', 'PeriodicJobs::CustomTable::ManageCustomTableUserSnapshots', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 */6 * * *', 'PeriodicJobs::CustomTable::ManageCtusForDeadlockUsers', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 7 * * *', 'PeriodicJobs::Pto::SendOverduePtoRequestEmail', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 7 * * *', 'PeriodicJobs::Pto::AutoCompletePtoRequest', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 4 * * *', 'PeriodicJobs::Emails::ApiKeyExpirationEmails', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('*/30 * * * *', 'PeriodicJobs::Emails::SendWelcomeEmail', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 3 * * *', 'PeriodicJobs::Users::SetUserCurrentStage', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::Users::OffboardUser', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::Pto::TriggerPtoCalculations', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::Reports::SendScheduledReports', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 1 * * *', 'PeriodicJobs::Integrations::SendEmployeesToBswift', queue: :critical_periodic_jobs, retry: 0, backtrace: true)

      mgr.register('30 4 * * *', 'PeriodicJobs::Integrations::Adp::PullEmployeesFromAdpWorkforceNow', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Bamboo::UpdateSaplingGroupsFromBamboo', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Bamboo::UpdateSaplingUsersFromBamboo', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::FifteenFive::UpdateSaplingUsersFromFifteenFive', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Peakon::UpdateSaplingUsersFromPeakon', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::LearnUpon::UpdateSaplingUsersFromLearnUpon', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Lessonly::UpdateSaplingUsersFromLessonly', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Namely::UpdateSaplingUsersFromNamely', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 4 * * *', 'PeriodicJobs::Integrations::Namely::ReceiveEmployeesProfileImageFromNamely', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Gusto::UpdateSaplingUsersFromGusto', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Lattice::UpdateSaplingUsersFromLattice', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 4 * * *', 'PeriodicJobs::Integrations::Onelogin::UpdateSaplingUsersFromOnelogin', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Gsuite::UpdateGoogleGroups', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 5 * * *', 'PeriodicJobs::Integrations::Deputy::UpdateSaplingUsersFromDeputy', queue: :critical_periodic_jobs, retry: 0, backtrace: true)

      mgr.register('0 * * * *', 'PeriodicJobs::AdminUsers::DeactivateExpiredUsers', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 5 * * *', 'PeriodicJobs::Integrations::Slack::SendIntegrationsApiErrorToSlack', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 8 * * *', 'PeriodicJobs::Integrations::Workday::UpdateSaplingUsersFromWorkday', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 5 * * 0', 'PeriodicJobs::Integrations::Workday::UpdateWorkdayProfilePhotosInSapling', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::Pto::AssignUnassignedPtoPolicies', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::Integrations::SmartRecruiters::ImportPendingHiresFromSmartRecruiters', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::Users::ActivitiesReminder', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::Emails::WeeklyTeamDigestEmail', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 9 * * *', 'PeriodicJobs::Activities::ScheduleTasks', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 12 * * *', 'PeriodicJobs::Integrations::Paylocity::PullPaylocityEmployee', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 2 * * SUN', 'PeriodicJobs::Integrations::Okta::SyncOktaEmployees', queue: :low_priority_periodic_jobs, backtrace: true, retry: 0)
      mgr.register('0 0 * * *', 'PeriodicJobs::Integrations::TeamSpirit::SendCsvFilesToTeamSpirit', queue: :low_priority_periodic_jobs, backtrace: true, retry: 0)
      mgr.register('0 2 * * SAT', 'PeriodicJobs::Emails::WeeklyMetricsEmail', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 0 * * SAT', 'PeriodicJobs::Integrations::Paylocity::PullCostCenterOptions', queue: :critical_periodic_jobs, retry: 0, backtrace: true)

	    mgr.register('0 * * * *', 'PeriodicJobs::Emails::WeeklyHiresEmail', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
	    mgr.register('0 */8 * * *', 'PeriodicJobs::Integrations::Asana::SyncTasksFromAsana', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
	    mgr.register('45 8 * * *', 'PeriodicJobs::CustomTable::ManageExpiredApprovalTypeCtus', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('30 12 * * *', 'PeriodicJobs::Company::UpdateOrganizationChart', queue: :low_priority_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('45 8 * * *', 'PeriodicJobs::CustomSection::ManageExpiredApprovalTypeCsApproval', queue: :critical_periodic_jobs, retry: 0, backtrace: true)

      mgr.register('*/2 * * * *', 'PeriodicJobs::Hellosign::HellosignCallsManagement', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 * * * *', 'PeriodicJobs::WebhookEvent::CreateKeyDateReachedWebhookEventsJob', queue: :webhook_activities, retry: 0, backtrace: true)
      mgr.register('0 9 * * *', 'PeriodicJobs::CompanyAttributes::SyncCompanyData', queue: :low_priority_periodic_jobs, backtrace: true, retry: 0)
      mgr.register('*/3 * * * *', 'PeriodicJobs::Hellosign::BulkHellosignCallsManagement', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('*/10 * * * *', 'PeriodicJobs::Documents::HandleBuggySignedDocumentsValidator', queue: :low_priority_periodic_jobs, backtrace: true, retry: 0)
      mgr.register('5 * * * *', 'PeriodicJobs::Documents::FixBuggySignedDocumentsDailyJob', queue: :document_validator, backtrace: true, retry: 0)

      mgr.register('0 0 * * *', 'PeriodicJobs::Integrations::Xero::PullEmployeesFromXeroJob', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
      mgr.register('0 */1 * * *', 'PeriodicJobs::TaskUserConnections::CompleteTaskFromServicenow', queue: :critical_periodic_jobs, retry: 0, backtrace: true)
    end

    config.error_handlers << Proc.new {|ex,ctx_hash| HealthCheck::HealthCheckService.new(ctx_hash[:job]['class']).ping_fail }
    config.death_handlers << Proc.new {|ctx_hash| HealthCheck::HealthCheckService.new(ctx_hash['class']).ping_fail }
  end

  Rails.logger = Sidekiq.logger
  ActiveRecord::Base.logger = Sidekiq.logger
  SidekiqUniqueJobs::Server.configure(config)
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['SIDEKIQ_REDIS_URL'], network_timeout: 5, pool_timeout: 5 }
  Sidekiq::Status.configure_client_middleware config, expiration: 1.day
  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end
