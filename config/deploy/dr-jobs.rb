server 'dr-jobs1.vpc.local', user: 'deployer', roles: %w{sidekiq cronjobs}

set :branch, 'master'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :production

namespace :deploy do

  desc 'Update crontab with whenever'
  task :update_cron do
    on roles(:cronjobs) do
      within current_path do
        execute :bundle, :exec, "whenever --update-crontab #{fetch(:application)}"
      end
    end
  end

  desc 'Run migration on all server'
  task :run_migration do
    on roles(:db) do
      within current_path do
        execute :bundle, :exec, "rails db:migrate RAILS_ENV=#{fetch(:stage)}"
      end
    end
  end

  after :finished, 'deploy:update_cron'
  after :finished, 'deploy:run_migration'

end