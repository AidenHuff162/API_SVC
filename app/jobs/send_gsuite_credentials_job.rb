class SendGsuiteCredentialsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(user_id, company_id)
    puts "---started send gsuite credentials job---"
    company = Company.find_by(id: company_id)
    if company.present?
      user = company.users.where(id: user_id).take
      if user && user.active?
        UserMailer.notify_user_about_gsuite_account_creation(user.id, company).deliver_now!
        user.update_column(:google_account_credentials_sent, true)
      end
    end
  end
end
