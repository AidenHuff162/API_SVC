class BulkOnboardUsersJob
  require 'sidekiq-pro' unless Rails.env.test?
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => 0, :backtrace => true

  def perform(params, company_id, current_user_id)
    BulkOnboardUsersService.new.perform(params, company_id, current_user_id)
  end
end
