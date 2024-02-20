namespace :update_email_templates_is_default_state do
  
  desc "Updating Email Templates is_default value"
  task :update => :environment do |t, args|
    companies = Company.all
    companies.find_each do |company|
      email_types = ['invitation', 'offboarding']
      
      email_types.each do |type|
        template = company.email_templates.where(email_type: type).order(:id)
        if template.present?
          template[0].update(is_default: true)
        end
      end
      company.email_templates.where.not(email_type: EmailTemplate::DEFAULT_NOTIFICATION_TEMPLATES).where(is_enabled: false).update_all(is_enabled: true)
      company.email_templates.where(email_type: 'invite_user').update_all(name: 'Invitation to Sapling')
    end
    puts "Task completed"
  end
end
