module Users
  class InitializeUserCurrentStageJob
    require 'sidekiq-pro'
    include Sidekiq::Worker
    sidekiq_options :queue => :default, :retry => 0, :backtrace => true

    def perform
      batch = Sidekiq::Batch.new
      batch.on(:complete, InitializeUserCurrentStageJob)

      batch.jobs do
  	    Company.active_companies.ids.each { |id| ::Users::SetUserCurrentStageJob.perform_async(id) }
      end
    end

    def on_complete(status, options)
      User.algolia_reindex 
    end
  end
end
