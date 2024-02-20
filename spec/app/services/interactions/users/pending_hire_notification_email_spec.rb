require 'rails_helper'

RSpec.describe Interactions::Users::PendingHireNotificationEmail do

  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
  end
  describe 'complete activities' do
    let!(:company) {create(:company, new_pending_hire_emails: true)}
    let!(:user) {create(:user, current_stage: :incomplete, company: company)}
    let!(:pending_hire) {create(:pending_hire, user: nil, personal_email: user.personal_email, company: company)}
    before { EmailTemplate.where(email_type: "new_pending_hire", company_id: company.id).first.update(email_to: "<p>sam@sam.com</p>")}

    context 'sending notification email' do
      it 'should send email' do
        expect{Interactions::Users::PendingHireNotificationEmail.new(pending_hire).perform}.to change{CompanyEmail.all.count}.by(1)
      end

      it 'should not send email if company dont allow' do
        company.update(new_pending_hire_emails: false)
        expect{Interactions::Users::PendingHireNotificationEmail.new(pending_hire).perform}.to change{CompanyEmail.all.count}.by(0)
      end
    end
  end    
end
