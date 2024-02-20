require 'csv'
class WriteApprovedCsaCSVJob
  include Sidekiq::Worker
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true
  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end

  def perform(company_id, user_id, send_email = false)
    EmailDashboardApprovedRequestsService.new.perform(company_id, user_id, send_email, FILE_STORAGE_PATH)
  end  
end
