require 'rails_helper'

RSpec.describe BulkOnboardingEmailsJob, type: :job do

  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }
  let!(:email_template) { create(:email_template, company: company) }

  it 'should run job and return true' do
    expect{ BulkOnboardingEmailsJob.new.perform(user.id, [email_template.id], user.id, user.onboarding_profile_template_id) }.to have_enqueued_job(SendUserEmailsJob)
  end
end