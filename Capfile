require 'capistrano/setup'
require 'capistrano/deploy'
require 'capistrano/scm/git'
require 'rvm1/capistrano3'
require 'capistrano/bundler'
require 'capistrano/rails'
require 'capistrano/sidekiq'
require 'bugsnag/capistrano'
require 'whenever/capistrano'
require 'capistrano/sidekiq/monit'
require 'new_relic/recipes'

install_plugin Capistrano::SCM::Git

Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
set :bugsnag_api_key, ENV['BUG_SNAG_API_KEY']
