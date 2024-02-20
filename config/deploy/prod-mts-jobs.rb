# jobs-app
server 'mts-jobs1.vpc.local', user: 'deployer', roles: %w{sidekiq}

set :branch, 'master'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :production

# Note: database migration performed only on web-app
namespace :deploy do

  desc 'Update crontab with whenever'
  task :update_cron do
    on roles(:cronjobs) do
      within current_path do
        execute :bundle, :exec, "whenever --update-crontab #{fetch(:application)}"
      end
    end
  end

  before :finished, 'sidekiq:quiet'
  after :finished, 'deploy:update_cron'
  after :finished, 'sidekiq:stop'
  after :finished, 'sidekiq:start'

end
