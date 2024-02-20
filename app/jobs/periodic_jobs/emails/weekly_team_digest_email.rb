module PeriodicJobs::Emails
  class WeeklyTeamDigestEmail
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::WeeklyTeamDigestEmail').ping_start
      
      now = Time.now.utc
      if [4,5,6].include?(now.wday)
        current_time_zones = get_time_zones
        if current_time_zones.present?
          Company.where(team_digest_email: true, time_zone: current_time_zones, account_state: "active").find_each do |company|
            ::WeeklyTeamDigestJob.perform_async(company.id)
          end
        end
      end
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::WeeklyTeamDigestEmail').ping_ok
    end

    def get_time_zones
      current_time_zones = []
      ActiveSupport::TimeZone.all.select do |time_zone|
        current_time_zones.push(time_zone.name) if time_zone.now.hour == 11 && time_zone.now.min.between?(0, 59) && time_zone.today.friday?
      end
      current_time_zones
    end
  end
end
