server '52.26.130.94', user: 'deployer', roles: %w{sidekiq cronjobs}

set :branch, 'master'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :staging

namespace :deploy do

  desc 'Update crontab with whenever'
  task :update_cron do
    on roles(:cronjobs) do
      within "#{current_path}" do
        execute :bundle, :exec, "whenever --update-crontab #{fetch(:application)}  --set environment=#{fetch(:stage)}"
      end
    end
  end

  after :finished, 'deploy:update_cron'

end
