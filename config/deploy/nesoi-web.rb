# web-app
server '52.26.45.151',  user: 'deployer', roles: %w{app db web}

set :branch, 'master'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :staging
set :rails_env, 'staging'

namespace :deploy do
  after :finished, 'app:restart'
end
