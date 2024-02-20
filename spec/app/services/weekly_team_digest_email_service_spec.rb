require 'rails_helper'

RSpec.describe WeeklyTeamDigestEmailService do
  let(:company) {create(:company, enabled_time_off: true, enabled_calendar: true)}
  let(:user) {create(:user, company: company)}
  let(:managed_user) {create(:user, company: company, manager_id: user.id)}
  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
    @date = company.time.to_date
    company.update(calendar_permissions: {"anniversary" => true, "birthday" => true})
  end
  describe 'digest email' do

    it 'should not send email if data is empty' do
      expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(0)
    end
    
    context 'anniversary data' do
      before do 
        managed_user.update(start_date: @date - 1.year)
      end
      it 'should  send email if data is present' do
        expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(1)
      end

      it 'should  send email if permission for anniversary not present is present' do
        company.update(calendar_permissions: {"anniversary" => false, "birthday" => true})
        expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(0)
      end
    end

    context 'birthday data' do
      let!(:custom_field_value) {create(:custom_field_value, value_text: @date, user: managed_user, custom_field: company.custom_fields.where(name: 'Date of Birth').first)}

      it 'should  send email if data is present' do
        expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(1)
      end

      it 'should  send email if permission for anniversary not present is present' do
        company.update(calendar_permissions: {"anniversary" => true, "birthday" => false})
        expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(0)
      end
    end

    context 'pto data' do
      before do
        Sidekiq::Testing.inline! do
          @pto_policy = FactoryGirl.create(:default_pto_policy, manager_approval: false, company: company)
        end
        managed_user.update(start_date: managed_user.start_date - 1.year)
        User.current = user
      end

      it 'should send email if pto begin data is present' do
        pto_request = FactoryGirl.create(:default_pto_request, user: managed_user, pto_policy: @pto_policy, begin_date: @date, end_date: @date, status: 1)
        expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(1)
      end

      it 'should send email if pto return data is present' do
        pto_request = FactoryGirl.create(:default_pto_request, user: managed_user, pto_policy: @pto_policy, begin_date: @date - 1.day, end_date: @date + 2.day, status: 1)
        expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(1)
      end

      it 'should not send email if time off disabled' do
        pto_request = FactoryGirl.create(:default_pto_request, user: managed_user, pto_policy: @pto_policy, begin_date: @date - 1.day, end_date: @date + 2.day, status: 1)
        company.update(enabled_time_off: false)
        expect{WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)}.to change{CompanyEmail.all.count}.by(0)
      end
    end

    context 'send email to current user' do
      before do
        Sidekiq::Testing.inline! do
          @pto_policy = FactoryGirl.create(:default_pto_policy, manager_approval: false, company: company)
        end
        managed_user.update(start_date: managed_user.start_date - 1.year)
        User.current = user
      end

      it 'should send email to user if current user not present' do
        pto_request = FactoryGirl.create(:default_pto_request, user: managed_user, pto_policy: @pto_policy, begin_date: @date, end_date: @date, status: 1)
        WeeklyTeamDigestEmailService.new(user).trigger_digest_email(@date, @date + 7.days)
        expect(CompanyEmail.order('id DESC').take.to[0]).to eq(user.get_present_email)
      end

      it 'should send email to current user if current user is present' do
        pto_request = FactoryGirl.create(:default_pto_request, user: managed_user, pto_policy: @pto_policy, begin_date: @date, end_date: @date, status: 1)
        WeeklyTeamDigestEmailService.new(user, managed_user).trigger_digest_email(@date, @date + 7.days)
        expect(CompanyEmail.order('id DESC').take.to[0]).to eq(managed_user.get_present_email)
      end
    end
  end
end
