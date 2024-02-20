# web-app
server 'proto0-api1.vpc.local',  user: 'deployer', roles: %w{app db}

# admin-app
# need web role for admin-app because we need to run assets precompile task on this server to load active admin UI
server 'proto0-admin1.vpc.local',  user: 'deployer', roles: %w{app db web}

set :branch, 'staging'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :staging
set :rails_env, 'staging'

namespace :deploy do

  desc 'Run rake task migration on all servers'
  task :run_rake_task_migration do
    on roles(:db) do
      within "#{current_path}" do
        execute :bundle, :exec, "rake tasks:migrate RAILS_ENV=#{fetch(:stage)}"
      end
    end
  end

  after :finished, 'deploy:run_rake_task_migration'
  after :finished, 'app:restart'

end
