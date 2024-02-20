require 'rails_helper'

RSpec.describe Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail do
  let!(:company) {create(:company, manager_form_emails: true)}
  let!(:user) {create(:user, company: company)}
  let!(:nick) {create(:nick, account_creator: user, company: company)}

  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
  end
  describe 'notify account creator' do
    it 'should notify account_creator' do
      Sidekiq::Testing.inline! do
        expect{Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(nick, nick.manager, user).perform}.to change{CompanyEmail.all.count}.by(1)
      end
    end

    it 'should notify account_creator, create history' do
      Sidekiq::Testing.inline! do
        Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(nick, nick.manager, user).perform
        expect(CompanyEmail.first.to[0]).to eq(user.email)
      end
    end

    it 'should create history' do
      expect{Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(nick, nick.manager, user).perform}.to change{History.all.count}.by(1)
    end

    it 'should enque job' do
      expect{Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(nick, nick.manager, user).perform}.to change{Sidekiq::Queues["slack_notification"].size}.by(1)
    end

    it 'should not notify if company not present' do
      company.update_column(:deleted_at, Time.now)
      expect{Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(nick, nick.manager, user).perform}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not notify if company do not allow manager_form_emails' do
      company.update_column(:manager_form_emails, false)
      expect{Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(nick, nick.manager, user).perform}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not notify if emoloyee do not have email_enabled' do
      nick.updated_from = "integration"
      expect{Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(nick, nick.manager, user).perform}.to change{CompanyEmail.all.count}.by(0)
    end

  end
end
