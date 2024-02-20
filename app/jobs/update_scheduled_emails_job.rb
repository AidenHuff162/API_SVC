class UpdateScheduledEmailsJob < ApplicationJob
  def perform(company_id, user_id, action)
    company = Company.find_by(id: company_id)
    user = company&.users&.find_by(id: user_id)
    return unless action.present? && user.present?

    begin
      action.each do |key|
        user.key_date_changed(key)
      end
    rescue Exception => e
      logging.create(company, 'Error during updating scheduled email', { user_id: user_id, error: e.message })
    end
  end

  private

  def logging
    @logging ||= LoggingService::GeneralLogging.new
  end
end
