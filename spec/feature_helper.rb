require 'rails_helper'
require 'capybara-screenshot/rspec'
require 'capybara/dsl'
require 'capybara/poltergeist'
# require 'knapsack'

# Knapsack.report.config({
#   report_path: 'knapsack_features_report.json'
# })

Dir[Rails.root.join('spec/features/support/**/*.rb')].each { |f| require f }

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    js_errors: false,
    phantomjs_options: ['--ignore-ssl-errors=yes', '--ssl-protocol=any'],
    debug: false,
    window_size: [1600, 1200],
    timeout: 30.minutes,
    extensions: [
       Rails.root.join('spec/features/support/phantomjs/disable_animations.js')
    ]
  })
end

RSpec.configure do |config|
 config.include Auth
 config.include General
end

Capybara.configure do |config|
  config.javascript_driver = :poltergeist
  config.server_host = 'foo.sapling.localhost'
  Capybara.server_port = 3001
  config.default_max_wait_time = 30
  config.app_host = 'http://foo.frontend.me:8081'
end
