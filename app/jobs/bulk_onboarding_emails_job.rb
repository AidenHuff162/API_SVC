class BulkOnboardingEmailsJob
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 0, backtrace: true

  def perform(user_id, template_ids, current_user_id, selected_profile_template_id)
    user = User.find_by(id: user_id)
    templates = EmailTemplate.where(id: template_ids)
    if user && templates
      user.destroy_all_incomplete_emails
      templates.each do |template|
        user.create_user_email(template, UserEmail.scheduled_froms[:onboarding], nil, current_user_id)
      end
      SendUserEmailsJob.perform_later(user.id, 'onboarding', true, nil, selected_profile_template_id)
    end
  end
end