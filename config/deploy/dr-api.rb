server 'dr-api1.vpc.local', user: 'deployer', roles: %w{app web db}

set :branch, 'master'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :production

namespace :deploy do

  desc 'Run migration on all servers'
  task :run_migration do
    on roles(:db) do
      within current_path do
        execute :bundle, :exec, "rails db:migrate RAILS_ENV=#{fetch(:stage)}"
      end
    end
  end

  desc 'Run rake task migration on all servers'
  task :run_rake_task_migration do
    on roles(:db) do
      within "#{current_path}" do
        execute :bundle, :exec, "rake tasks:migrate RAILS_ENV=#{fetch(:stage)}"
      end
    end
  end

  after :finished, 'deploy:run_migration'
  after :finished, 'deploy:run_rake_task_migration'
  after :finished, 'app:restart'

end