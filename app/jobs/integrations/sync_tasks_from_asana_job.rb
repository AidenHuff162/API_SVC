module Integrations
  class SyncTasksFromAsanaJob
    include Sidekiq::Worker
    sidekiq_options queue: :asana_integration, retry: false, backtrace: true

    def perform
      AsanaService::SyncTasks.new.perform
    end

  end
end
