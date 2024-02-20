module Users
  class SetUserCurrentStageJob
    include Sidekiq::Worker
    sidekiq_options :queue => :user_current_stage, :backtrace => true, :retry => false

    def perform(company_id)
      company = Company.find_by_id company_id
      Interactions::Users::SetUserCurrentStage.new.perform(company) if company
    end
  end
end
