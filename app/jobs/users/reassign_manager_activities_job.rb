class Users::ReassignManagerActivitiesJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(company_id, user_id, previous_manager_id)
  	company = Company.find_by(id: company_id)
  	return unless company.present? && user_id.present?
    ReassignManagerActivitiesService.new(company, user_id, previous_manager_id).perform()
  end
end