class BulkInvitesJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(user_ids, company_id)
    company = Company.find_by(id: company_id)
    if company.present? && !user_ids.empty?
      company.users.where(id: user_ids).each do |user|
        Interactions::Users::SendInvite.new(user.id, true, true).perform
      end
    end
  end

end
