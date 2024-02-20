namespace :update_manager_buddy_email_template do
  desc 'Task manager buddy email templates update'
  task update_manager_buddy_email_template: :environment do
    Company.find_each do |company|
      company.update_manager_buddy_email_template
    end
    puts 'Task successfully completed.'
  end
end
