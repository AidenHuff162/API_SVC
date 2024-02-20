class ResetCounter::ResetCounterCompanyRelatedJob < ApplicationJob
  queue_as :reset_company_related_counters

  def perform
    Company.where(deleted_at: nil, account_state: :active).find_each do |c|
      Company.reset_counters(c.id, :users)
      Company.reset_counters(c.id, :locations)
      Company.reset_counters(c.id, :teams)
    end
  end
end
