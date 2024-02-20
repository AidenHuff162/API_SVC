module Loggings
  class ExportLoggingsToAdminUserJob
    require 'rake'
    include Sidekiq::Worker
    sidekiq_options queue: :export_loggings, retry: false, backtrace: true

    def perform(args)
      execute_export_loggings_service(args)
    end

    private

    def execute_export_loggings_task(args)
      Rails.application.load_tasks
      Rake::Task['export_active_admin_loggings:email_loggings_csv_to_admin_user'].invoke(args.with_indifferent_access)
    end

    def execute_export_loggings_service(args)
      LoggingService::ExportLoggingsToAdminUser.call(args.with_indifferent_access)
    end

  end
end
