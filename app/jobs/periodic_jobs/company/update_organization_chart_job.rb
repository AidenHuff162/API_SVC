module PeriodicJobs::Company
  class UpdateOrganizationChart
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Company::UpdateOrganizationChart').ping_start
      ::Company::UpdateOrganizationChartForCompany.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Company::UpdateOrganizationChart').ping_ok
    end
  end
end
