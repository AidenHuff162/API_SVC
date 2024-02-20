ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)

abort('The Rails environment is running in production mode!') if Rails.env.production?

if ENV['CI'] == 'true'
  ENV['DEFAULT_HOST'] = 'sapling.localhost'
end

require 'spec_helper'
require 'rspec/rails'
require 'shoulda/matchers'
require 'database_cleaner'
require 'support/authentication_helper'

load File.join(Rails.root, 'Rakefile')

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.use_transactional_fixtures = false

  config.include Devise::TestHelpers, type: :routing
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::TestHelpers, type: :view
  config.include FactoryGirl::Syntax::Methods
  config.include AbstractController::Translation
  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  config.include ActiveJob::TestHelper, type: :job
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
