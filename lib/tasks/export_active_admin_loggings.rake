namespace :export_active_admin_loggings do
  desc "it compiles the loggings into csv and emails to the admin user"
  task :email_loggings_csv_to_admin_user, [:args] do |_task, params_args|
    
    puts "... Active Admin logs fetching started with parameters #{params_args} ..."
    LoggingService::ExportLoggingsToAdminUser.call(params_args[:args])
    puts "... Prepared logs CSV and emailed to Admin User ..."
  
  end
end