class ResetCounter::ResetCounterUserRelatedJob < ApplicationJob
  queue_as :reset_user_related_counters

  def perform(company_id)
    company = Company.find_by(id: company_id)
    return unless company.present?
    company.users.try(:find_each) do |user| ResetCounter::ResetIndividualUserCounterJob.perform_async(company.id, user.id) end
  end
end
