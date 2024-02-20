namespace :fix_counters do
  desc 'Reset Counters for location_users'
  task location_users: :environment do
    Location.find_each { |loc| Location.reset_counters(loc.id, :users) }
  end

  desc 'Reset Counters for team_users'
  task team_users: :environment do
    Team.find_each { |team| Team.reset_counters(team.id, :users) }
  end

  desc 'Reset Counters for company_users, company_locations, and company_teams'
  task company_tasks: :environment do
    ResetCounter::ResetCounterCompanyRelatedJob.perform_later
  end

  desc 'Reset Counters for workstream_tasks'
  task workstream_tasks: :environment do
    Workstream.find_each { |w| Workstream.reset_counters(w.id, :tasks) }
  end

  desc 'Reset Counters for task_user_connections, paperwork_requests, and user_document_connections'
  task user_related_counter_tasks: :environment do
    Company.where(deleted_at: nil, account_state: :active).find_each { |company| ResetCounter::ResetCounterUserRelatedJob.perform_later(company.id) }  
  end

  desc 'Reset Counters for users'
  task users: :environment do
    User.counter_culture_fix_counts
  end

  desc 'Execute all reset counter tasks'
  task all: [:location_users, :team_users, :company_tasks, :workstream_tasks, :user_related_counter_tasks, :users]
end
