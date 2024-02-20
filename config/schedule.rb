require 'yaml'
require 'net/http'
require 'openssl'
require 'json'

PATH = File.dirname(__FILE__) + '/bootstrap.yml'
ENV = YAML.load_file(PATH) rescue {}

ENV['FETCH_ENVS_FROM_REMOTE_URL'] = 'false' if ENV.nil?

if ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
  begin
    if ENV['CRONJOB_HEALTH_CHECK_CONFIG_URL'].include?(".json")
      uri = URI.parse(ENV['CRONJOB_HEALTH_CHECK_CONFIG_URL'])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(ENV['REMOTE_CONFIG_ACCESS_USERNAME'], ENV['REMOTE_CONFIG_ACCESS_PASSWORD'])
      response = http.request(request)
      HEALTH_CHECK_CONFIG =  JSON.parse(response.body)
    end
  rescue Exception => e
    puts e
  end
else
  PATH = File.dirname(__FILE__) + '/health_check.yml'
  HEALTH_CHECK_CONFIG = YAML.load_file(PATH)
end

job_type :sapling_runner, "cd /home/deployer/www/sapling/current && bundle exec bin/rails runner -e #{@environment} :task :ping_health"
job_type :sapling_rake, "cd /home/deployer/www/sapling/current  && RAILS_ENV=#{@environment} bundle exec rails :task :ping_health"

every 30.minutes, roles: [:cronjobs, :sidekiq, :app] do
  sapling_rake "log:archive", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['LOG_ARCHIVE']} > /dev/null"
  #rake "log:archive"
end

# every 1.day, at: '01:00 am', roles: :cronjobs do
#   sapling_runner "'RecurringJobs::Users::CreateUserCalendarEvent.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['CREATE_USER_CALENDAR_EVENT']} > /dev/null"
#   #runner "RecurringJobs::Users::CreateUserCalendarEvent.new.perform"
# end

# every 1.day, at: '01:30 am', roles: :cronjobs do
#   sapling_runner "'RecurringJobs::Users::RemoveExpiredGhostUsers.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['REMOVE_EXPIRED_GHOST_USERS']} > /dev/null"
#   #runner "RecurringJobs::Users::RemoveExpiredGhostUsers.new.perform"
# end

# every 1.day, at: '01:30 am', roles: :cronjobs do
  # sapling_rake "uploaded_files:remove_expired", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['UPLOADED_FILES_REMOVED_EXPIRED']} > /dev/null"
  #rake "uploaded_files:remove_expired"
# end

# every 1.day, at: '01:30 am', roles: :cronjobs do
  # sapling_rake "fix_counters:all", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['FIX_COUNTERS']} > /dev/null"
  #rake "fix_counters:all"
# end

# every 1.day, at: '01:30 am', roles: :cronjobs do
#   sapling_runner "'RecurringJobs::PaperTrail::RemoveOldVersion.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['REMOVE_OLD_VERSION']} > /dev/null"
#   #runner "RecurringJobs::PaperTrail::RemoveOldVersion.new.perform"
# end

# every 30.minutes, roles: :cronjobs do
#   sapling_runner "'RecurringJobs::Users::SendWelcomeEmail.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['RECURRINGJOBS_USERS_SEND_WELCOME_EMAIL']} > /dev/null"
#   #runner "RecurringJobs::Users::SendWelcomeEmail.new.perform"
# end

# every 1.day, at: '03:00 am', roles: :cronjobs do
#   sapling_runner "'RecurringJobs::Users::SetUserCurrentStage.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['RECURRINGJOBS_USERS_SET_USER_CURRENTSTAGE']} > /dev/null"
#   #runner "RecurringJobs::Users::SetUserCurrentStage.new.perform"
# end

# every :hour, roles: :cronjobs do
#   sapling_runner "'RecurringJobs::Users::OffboardUser.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['USERS_OFFBOARD_USER']} > /dev/null"
#   #runner "RecurringJobs::Users::OffboardUser.new.perform"
# end

# every :hour, roles: :cronjobs do
#   sapling_runner "'SendScheduledReports.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['SEND_SCHEDULED_REPORTS']} > /dev/null"
#   #runner "SendScheduledReports.new.perform"
# end

if @environment == 'production'
  # every :hour, roles: :cronjobs do
  #   sapling_runner "'Interactions::Integrations::ImportPendingHiresFromSmartRecruiters.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['IMPORT_PENDING_HIRES_FROM_SMART_RECRUITERS']} > /dev/null"
  #   #runner 'Interactions::Integrations::ImportPendingHiresFromSmartRecruiters.new.perform'
  # end

  # every :hour, roles: :cronjobs do
  #   sapling_runner "'RecurringJobs::Users::ActivitiesReminder.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['ACTIVITIES_REMINDER']} > /dev/null"
  #   #runner 'RecurringJobs::Users::ActivitiesReminder.new.perform'
  #   sapling_runner "'RecurringJobs::AdminUsers::DeactivateExpiredUsers.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['DEACTIVATE_EXPIRED_USERS']} > /dev/null"
  #   #runner 'RecurringJobs::AdminUsers::DeactivateExpiredUsers.new.perform'
  #   sapling_runner "'RecurringJobs::WeeklyTeamDigestEmail.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['WEEKLY_TEAM_DIGEST_EMAIL']} > /dev/null"
  #   #runner 'RecurringJobs::WeeklyTeamDigestEmail.new.perform'
  # end

  # every 1.day, at: '09:00 am', roles: :cronjobs do
  #   sapling_runner "'RecurringJobs::Activities::ScheduleTasks.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['ACTIVITIE_SCHEDULE_TASKS']} > /dev/null"
  #  #runner 'RecurringJobs::Activities::ScheduleTasks.new.perform'
  # end

  # every :saturday, at: '2:00 am', roles: :cronjobs do
  #   sapling_runner "'RecurringJobs::WeeklyMetricsEmail.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['WEEKLY_METRICS_EMAIL']} > /dev/null"
  #   #runner 'RecurringJobs::WeeklyMetricsEmail.new.perform'
  # end
end

# every :hour, roles: :cronjobs do
#   sapling_runner "'RecurringJobs::WeeklyHiresEmail.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['WEEKLY_HIRES_EMAIL']} > /dev/null"
#   #runner "RecurringJobs::WeeklyHiresEmail.new.perform"
# end

# every 30.minutes, roles: :cronjobs do
#   sapling_runner "'Interactions::CustomTables::ManageCustomTableUserSnapshots.new.perform'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['MANAGE_CUSTOM_TABLE_USER_SNAPSHOTS']} > /dev/null"
#   #runner "Interactions::CustomTables::ManageCustomTableUserSnapshots.new.perform"
# end

# every :hour, roles: :cronjobs do
#   rails 'sapling:regenerate_organization_chart'
# end

# every 1.day, at: '08:45 am', roles: :cronjobs do
#   sapling_runner "'Interactions::CustomTables::ManageExpiredApprovalTypeCtus.new.execute'", ping_health: " && curl -fsS --retry 3 #{HEALTH_CHECK_CONFIG['MANAGE_EXPIRED_APPROVAL_TYPE_CTUS']} > /dev/null"
#   #runner "Interactions::CustomTables::ManageExpiredApprovalTypeCtus.new.execute"
# end
