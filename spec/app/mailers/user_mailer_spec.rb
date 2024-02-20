require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do

  context '#onboarding_email' do

    subject(:email) { UserMailer.onboarding_email(invite) }
    let(:company) { create(:company, owner: build(:user)) }
    let(:user) { create(:user, company: company, onboard_email: 1) }
    let(:invite){ create(:invite, user: user) }

    # Update email specs after getting testing keys for sendgrid API
    # it 'delivers onboarding email to user' do
    #   is_expected.to deliver_to(user.email)
    # end

    # it 'has the correct link' do
    #   is_expected.to have_body_text(root_url(domain: company.domain))
    # end
  end

  context '#preboarding_email' do

    let(:company) { create(:company, owner: build(:user)) }
    let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
    let(:user) { create(:user, company: company, manager_id: user1.id) }
    let(:template) {EmailTemplate.where(email_type: "preboarding", company_id: user.company_id).first}

    it 'delivers preboarding email to user' do
      UserMailer.preboarding_complete_email(user, template).deliver
    end
  end

  context '#notify_user_about_gsuite_account_creation' do
    let(:company) { create(:company) }
    let(:user) { create(:user, company: company, gsuite_initial_password: "ABC@@!!12#3") }

    # before do
    #   @credentials_mail = UserMailer.notify_user_about_gsuite_account_creation(user.id, company)
    # end
    #
    # it 'send email with GSuite email and passowrd' do
    #   @credentials_mail.should have_body_text(/ABC@@!!12#3/)
    # end

  end

end
