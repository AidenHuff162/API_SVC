# admin-app
# need web role for admin-app because we need to run assets 
# precompile task on this server to load active admin UI

server 'mts-admin1.vpc.local',  user: 'deployer', roles: %w{app db web}

set :branch, 'master'
set :deploy_to, '/home/deployer/www/sapling'
set :stage, :production

# Do not run database migrations 
# Run migrations only on webapp (prod-mts-web.rb)

namespace :deploy do
  after :finished, 'app:restart'
end
