require 'rails_helper'

RSpec.describe Invite, type: :model do
  subject(:invite) { create(:invite) }

  describe 'Associations' do
    it { is_expected.to belong_to(:user)}
    it { is_expected.to have_many(:attachments).class_name('UploadedFile::Attachment').dependent(:destroy) }
  end

  describe 'Callbacks' do
    describe 'Before Validation' do
      context 'without token' do
        subject(:invite) { build(:invite) }

        it 'generates token' do
          invite.save
          expect(invite.reload.token).not_to be_nil
        end
      end

      context 'with token' do
        subject(:invite) { build(:invite, token: '12345678') }

        it 'keeps old token' do
          invite.save
          expect(invite.reload.token).to eq('12345678')
        end
      end
    end

    describe 'after_create' do
      context 'with GSuite integration enabled' do

        before(:each) do
          stub_request(:post, "https://www.googleapis.com/admin/directory/v1/users").to_return(body: %Q({:success=>{:primary_email=>'nick@rship.com'}}))
          company = create(:company, subdomain: 'invite_bar')
          gsuite = create(:gsuite_integration_instance, company: company)
          @nick = create(:nick, email: 'nick@rship.com', company: company)
          @mailer_queue_size = Sidekiq::Queues["mailers"].size
          user_email = create(:user_email, user: @nick)
          create(:invite_with_user_email, user_email: user_email, user: @nick)
        end

        it 'set users gsuite initial password,sets gsuite account exists to true,scheudles a mail to be sent via mailer' do
          expect(@nick.gsuite_initial_password).to_not eq(nil)
          expect(@nick.gsuite_account_exists).to eq(true)
          expect(Sidekiq::Queues["mailers"].size).to eq(@mailer_queue_size + 1)
        end

      end

      context 'with gsuite account enabled and send_credentials_type set to 2' do
        before(:all) do
          stub_request(:post, "https://www.googleapis.com/admin/directory/v1/users").to_return(body: %Q({:success=>{:primary_email=>'user@rship.com'}}))
          company = create(:company, subdomain: 'invite_bar')
          gsuite = create(:gsuite_integration_instance, company: company)
          user = create(:nick, email: 'usertest@rship.com', personal_email: 'test.personal@mail.com', company: company, start_date: company.time.to_date + 6.days, send_credentials_type: 2, send_credentials_timezone: 'Pacific/Pago_Pago')
          @user_email = create(:user_email, user: user)
        end

        it 'scheudles email on start date if start date is of future' do
          expect{create(:invite_with_user_email, user_email: @user_email, user: @user_email.user)}.to change(SendGsuiteCredentialsJob.jobs, :size).by(1)
        end

      end
    end

    describe 'After create invite' do
      subject(:invite) {FactoryGirl.create(:invite)}
      context 'create anniversaries calender event' do
        it 'should create default 10 years anniversaries' do
          anniversaries_events = invite.user_email.user.calendar_events.where(event_type: CalendarEvent.event_types[:anniversary])
          expect(anniversaries_events.count).to eq(10)
        end
        it 'first anniversary should be after six months of joining data' do
          first_anniversary = invite.user_email.user.calendar_events.where(event_type: CalendarEvent.event_types[:anniversary]).order(event_start_date: :asc).first
          expect(first_anniversary.event_start_date).to eq(invite.user_email.user.start_date + 6.months)
        end
      end

      context 'create start date calender event' do
        it 'should create event on calendar on the joining date for the user' do
          start_date_event = invite.user_email.user.calendar_events.where(event_type: CalendarEvent.event_types[:start_date]).take
          expect(start_date_event.event_start_date).to eq(invite.user_email.user.start_date)
        end
      end
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:user_email) }
  end
end
