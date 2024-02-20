# require File.expand_path('../boot', __FILE__) #RAILS 4
require './app/middlewares/company_middleware.rb'
require './lib/env_configurations.rb'
require './lib/ext/string.rb'
require_relative 'boot' #RAILS 5 CONFIG
require 'aws-sdk-secretsmanager'
require 'csv'
require 'rails/all'
require 'sidekiq-limit_fetch'

Log = Logger.new(STDOUT);
Log.level  = Logger::DEBUG

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sapling
  class Application < Rails::Application
    extend EnvConfigurations

    initialize_env_configurations()
    
    config.load_defaults 6.0
    config.autoloader = :classic

    config.autoload_paths += ["#{config.root}/lib"]
    config.eager_load_paths += ["#{config.root}/lib"]
    config.eager_load_paths += ["#{config.root}/app/jobs"]

    #Use rails 4 configuration
    config.active_record.belongs_to_required_by_default = false
    config.enable_dependency_loading = true

    config.middleware.use CompanyMiddleware
    # config.api_only = true
    config.middleware.use ActionDispatch::Flash
    config.middleware.use Rack::MethodOverride
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
    config.middleware.use Rack::Attack
    config.session_store :cookie_store

    Sidekiq::Logging.logger = ActiveSupport::TaggedLogging.new(Logger.new(
      Rails.root.join('log', "#{Rails.env}.log")
    ))

    Sidekiq::Extensions.enable_delay!

    # config.api_only = true
    if ['test', 'development'].include?(Rails.env)
      config.middleware.insert_before 0, Rack::Cors do
        allow do
          origins '*'
          resource '*',
          :headers => :any,
          :expose  => ['access-token', 'expiry', 'token-type', 'uid', 'client'],
          :methods => [:get, :post, :options, :delete, :put, :patch]
        end
      end
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: true
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
      g.orm :active_record
    end


    config.action_view.sanitized_allowed_attributes = ['href', 'title', 'style', 'dir', 'src', 'width', 'height']
    config.action_view.sanitized_allowed_tags = ['var', 'span', 'cite', 'address', 'strong', 'em', 'a', 'b', 'img',
      'p', 'blockquote', 's', 'ol', 'ul', 'li', 'pre', 'hr', 'br', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'address',
      'div', 'small', 'ins', 'q'
    ]

    #TODO: move these to application.yaml for each environment
    LOGIN_ATTEMPTS = { user: 6, admin: 3 }
    ONBOARDING_DAYS = 14
    ONBOARDING_DAYS_AGO = 14.days.ago
    HELLOSIGN_CLIENT_ID = ENV['HELLOSIGN_CLIENT_ID']
    ALGOLIA_APPLICATION_ID = ENV['ALGOLIA_APPLICATION_ID']
    ALGOLIA_ADMIN_KEY = ENV['ALGOLIA_ADMIN_KEY']
    EMPTY_BODY = ''
    config.active_job.queue_adapter = :sidekiq
  end
end
