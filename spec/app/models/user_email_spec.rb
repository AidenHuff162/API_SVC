require 'rails_helper'

RSpec.describe UserEmail, type: :model do
  let(:user_email) { create(:user_email) }

  describe 'Associations' do
    it { is_expected.to have_many(:attachments).class_name('UploadedFile::Attachment') }
    it { is_expected.to belong_to(:user) }
  end

  describe "Validations" do
    it 'Checks if record is invalid without user_id' do
      ue = UserEmail.new(subject: '', description: '', cc: '', bcc: '')
      expect(ue).to_not be_valid
    end
  end

  describe "#setup_recipients" do

    before do
      company = FactoryGirl.create(:company, notifications_enabled: true, preboarding_complete_emails: true, enabled_time_off: true)
      sarah = FactoryGirl.create(:sarah, company: company)
      @nick = FactoryGirl.create(:nick, manager_id: sarah.id)
    end

    it 'should setup recipient of user email if to as "personal" ' do
      params = {to: 'personal' ,from: 'sukhi@test.com',email_type: 'No Template', subject: 'Test Email', description: 'This is test email', cc: '', bcc: ''}
      ue = @nick.user_emails.new(params)
      ue.setup_recipients(params[:to])
      expect(ue.to).to eql([@nick.personal_email])
    end

    it 'should setup recipient of user email if to as "company" ' do
      params = {to: 'company' ,from: 'sukhi@test.com',email_type: 'No Template', subject: 'Test Email', description: 'This is test email', cc: '', bcc: ''}
      ue = @nick.user_emails.new(params)
      ue.setup_recipients(params[:to])
      expect(ue.to).to eql([@nick.email])
    end

    it 'should setup recipient of user email if to as "both" ' do
      params = {to: 'both' ,from: 'sukhi@test.com',email_type: 'No Template', subject: 'Test Email', description: 'This is test email', cc: '', bcc: ''}
      ue = @nick.user_emails.new(params)
      ue.setup_recipients(params[:to])
      expect(ue.to).to eql([@nick.personal_email,@nick.email])
    end

  end

  describe "#completed!" do
    it 'should update status to complete ' do
      user_email.completed!
      expect(user_email.email_status).to eq(3)
    end
  end

  describe "#deleted!" do
    it 'should update status to deleted ' do
      user_email.deleted!
      expect(user_email.email_status).to eq(2)
    end
  end

  describe "#scheduled!" do
    it 'should update status to scheduled ' do
      user_email.scheduled!
      expect(user_email.email_status).to eq(0)
    end
  end

  describe "#send_user_email!" do
    it 'should send default user email ' do
      allow_any_instance_of(Interactions::UserEmails::ScheduleCustomEmail).to receive(:perform).and_return(true)
      res = user_email.send_user_email
      expect(res).to eq(true)
    end

    it 'should send offboarding user email ' do
      allow_any_instance_of(Interactions::UserEmails::ScheduleCustomEmail).to receive(:perform).and_return(true)
      user_email.update(email_type: 'offboarding')
      res = user_email.send_user_email
      expect(res).to eq(true)
    end
  end

  describe "#get_to_email_list!" do
    it 'should get to email list ' do
      emails = user_email.get_to_email_list
      expect(emails.count).to eq(2)
    end

    it 'should send user emails' do
      user_email.update(email_status: 3)
      emails = user_email.get_to_email_list
      expect(emails.count).to eq(2)
    end

    it 'should return user emails' do
      user_email.update(invite_at: Time.now)
      emails = user_email.get_to_email_list
      expect(emails.count).to eq(2)
    end

    it 'should return onboarding user emails' do
      user_email.update(scheduled_from: 'onboarding')
      emails = user_email.get_to_email_list
      expect(emails.count).to eq(2)
    end

    it 'should return onboarding and personal user emails' do
      user_email.update(scheduled_from: 'onboarding')
      user_email.user.update(onboard_email: 'personal')
      emails = user_email.get_to_email_list
      expect(emails.count).to eq(1)
    end

    it 'should return onboarding and company emails' do
      user_email.update(scheduled_from: 'onboarding')
      user_email.user.update(onboard_email: 'company')
      emails = user_email.get_to_email_list
      expect(emails.count).to eq(1)
    end

    it 'should send onboarding and both emails' do
      user_email.update(scheduled_from: 'onboarding')
      user_email.user.update(onboard_email: 'both')
      emails = user_email.get_to_email_list
      expect(emails.count).to eq(2)
    end
  end

  describe "#time_wrt_company_timezone!" do
    it 'should return nil if invite_at is not set' do
      res = user_email.time_wrt_company_timezone
      expect(res).to eq(nil)
    end
  end

  describe "#replace_tokens!" do
    it 'should replace tokens and return email' do
      res = user_email.replace_tokens
      expect(res.present?).to eq(true)
    end
  end

  describe "#destroy!" do
    it 'should destroy email' do
      user_email.destroy
      expect(user_email.deleted_at.present?).to eq(true)
    end
  end

  describe "#set_send_at!" do
    it 'should return company time' do
      time = user_email.set_send_at
      expect(time.to_date).to eq(user_email.company_time.to_date)
    end

    it 'should return invite_at' do
      user_email.update(invite_at: Time.now)
      time = user_email.set_send_at
      expect(time).to eq(user_email.invite_at)
    end
  end

  describe "#check_valid_schedule_options" do
    it 'should check default valid schedule options' do
      res = user_email.check_valid_schedule_options
      expect(res).to eq(nil)
    end

    it 'should check valid schedule options for relative_key as anniversary' do
      user_email.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>nil, "relative_key"=>'anniversary', "duration_type"=>nil}
      user_email.save
      res = user_email.check_valid_schedule_options
      expect(res).to eq(nil)
    end

    it 'should check valid schedule options for relative_key as last day worked' do
      user_email.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>nil, "relative_key"=>'last day worked', "duration_type"=>nil}
      user_email.save
      res = user_email.check_valid_schedule_options
      expect(res).to eq("Set last day worked first for this new hire or change the scheduled date")
    end

    it 'should check valid schedule options for relative_key as last day worked today' do
      user_email.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>nil, "relative_key"=>'last day worked', "duration_type"=>nil}
      user_email.save
      user_email.user.update(last_day_worked: Date.today)
      res = user_email.check_valid_schedule_options
      expect(res).to eq(nil)
    end

    it 'should check valid schedule options for relative_key as date of termination' do
      user_email.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>nil, "relative_key"=>'date of termination', "duration_type"=>nil}
      user_email.save
      res = user_email.check_valid_schedule_options
      expect(res).to eq("Set date of termination first for this new hire or change the scheduled date")
    end

    it 'should check valid schedule options for relative_key as date of termination today' do
      user_email.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>nil, "relative_key"=>'date of termination', "duration_type"=>nil}
      user_email.save
      user_email.user.update(termination_date: Date.today)
      res = user_email.check_valid_schedule_options
      expect(res).to eq(nil)
    end

    it 'should check valid schedule options for relative_key as birthday' do
      user_email.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>nil, "relative_key"=>'birthday', "duration_type"=>nil}
      user_email.save
      res = user_email.check_valid_schedule_options
      expect(res).to eq("Set a birth date first for this new hire or change the scheduled date")
    end

    it 'should check valid schedule options for due before' do
      user_email.schedule_options = {"due"=>'before', "date"=>nil, "time"=>nil, "duration"=>1, "send_email"=>0, "relative_key"=>nil, "duration_type"=>'days'}
      user_email.save
      res = user_email.check_valid_schedule_options
      expect(res).to eq(nil)
    end

    it 'should check valid schedule options for due after' do
      user_email.schedule_options = {"due"=>'after', "date"=>nil, "time"=>nil, "duration"=>1, "send_email"=>0, "relative_key"=>nil, "duration_type"=>'days'}
      user_email.save
      res = user_email.check_valid_schedule_options
      expect(res).to eq(nil)
    end
  end
end
