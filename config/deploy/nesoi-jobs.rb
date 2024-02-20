# jobs-app
server '34.210.168.242', user: 'deployer', roles: %w{app cronjobs sidekiq}

set :branch, 'staging'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :staging

# Note: database migration performed only on web-app
namespace :deploy do

  desc 'Update crontab with whenever'
  task :update_cron do
    on roles(:cronjobs) do
      within current_path do
        execute :bundle, :exec, "whenever --update-crontab #{fetch(:application)} --set environment=#{fetch(:stage)}"
      end
    end
  end

  after :finished, 'deploy:update_cron'
  after :finished, 'sidekiq:restart'

end
