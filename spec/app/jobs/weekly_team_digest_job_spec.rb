require 'rails_helper'

RSpec.describe WeeklyTeamDigestJob, type: :job do
  let(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }
  let!(:managed_user1) { create(:user, company: company, manager: user) }
  let!(:managed_user2) { create(:user, company: company, manager: user) }
  before do
    company.update(calendar_permissions: {"anniversary" => true, "birthday" => true})
    managed_user1.update(start_date: (company.time.to_date - 1.year) + 4.days)
  end
  describe 'weekly team digest' do

    it 'should send email if user is present with managed users' do
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(1)
    end

    it 'should not send email if user is inactive' do
      user.update(state: 'inactive')
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not send email if current stage is incomplete' do
      user.update(current_stage: :incomplete)
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not send email if current stage is departed' do
      user.update(current_stage: :departed)
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not send email if current stage is offboarding' do
      user.update(current_stage: :offboarding)
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not send email if current stage is last_month' do
      user.update(current_stage: :last_month)
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not send email if current stage is last_week' do
      user.update(current_stage: :last_week)
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not send email if managed user are not present' do
      user.update(managed_user_ids: [])
      expect{WeeklyTeamDigestJob.new.perform(company.id)}.to change{CompanyEmail.all.count}.by(0)
    end

    it 'should not send email if company not present' do
      expect{WeeklyTeamDigestJob.new.perform(2342)}.to change{CompanyEmail.all.count}.by(0)
    end
  end
end