# Create all existing companies as launchdarkly users
namespace :launchdarkly do
  task create_user: :environment do
    Rails.configuration.ld_client =
      LaunchDarkly::LDClient.new(ENV['LAUNCH_DARKLY_KEY'])
    Company.create_launchdarkly_users_for_existing_companies
  end
end
