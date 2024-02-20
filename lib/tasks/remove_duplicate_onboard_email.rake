task remove_duplicate_onboard_notification_templates: :environment do
  Company.all.each do |company|
    if company.email_templates.where(email_type: 'onboarding_activity_notification').size > 1
      company.email_templates.where(email_type: 'onboarding_activity_notification').each do |email|
        if company.email_templates.where(email_type: 'onboarding_activity_notification').size > 1 and email.created_at == email.updated_at
          puts "+++ destroyed for company #{company.name} email #{email.id} +++++"
          email.destroy
        end
      end
    end
  end
end
