require 'rails_helper'

RSpec.describe Inbox::TriggerTestEmail do
  let!(:company) {create(:company)}
  let(:email_template) { create(:email_template, company: company) }
  let(:user) { create(:user, super_user: true, company: company) }
 

  describe 'Business Logic' do  
    it 'sends email template for manager_form' do
      email_template.update(email_type: 'manager_form')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for new_manager_form' do
      email_template.update(email_type: 'new_manager_form')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for new_manager' do
      email_template.update(email_type: 'new_manager')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for new_buddy' do
      email_template.update(email_type: 'new_buddy')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for onboarding_activity_notification' do
      email_template.update(email_type: 'onboarding_activity_notification')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for transition_activity_notification' do
      email_template.update(email_type: 'transition_activity_notification')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for offboarding_activity_notification' do
      email_template.update(email_type: 'offboarding_activity_notification')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for preboarding' do
      email_template.update(email_type: 'preboarding')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for offboarding' do
      email_template.update(email_type: 'offboarding')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for document_completion' do
      email_template.update(email_type: 'document_completion')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for invitation' do
      email_template.update(email_type: 'invitation')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for welcome_email' do
      email_template.update(email_type: 'welcome_email')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for new_pending_hire' do
      email_template.update(email_type: 'new_pending_hire')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for start_date_change' do
      email_template.update(email_type: 'start_date_change')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

    it 'sends email template for invite_user' do
      email_template.update(email_type: 'invite_user')
      ::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })
      expect {::Inbox::TriggerTestEmail.call(user, { email_type: email_template.email_type, subject: email_template.subject, description: email_template.description, cc: email_template.cc, bcc: email_template.bcc, schedule_options: email_template.schedule_options, attachment_ids: email_template.attachment_ids })}.not_to raise_error
    end

  end
end



