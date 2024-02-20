# web-app
server 'stage-api1.vpc.local',  user: 'deployer', roles: %w{app db web}


set :branch, 'master'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :staging
set :rails_env, 'staging'

namespace :deploy do
  after :finished, 'app:restart'
end
