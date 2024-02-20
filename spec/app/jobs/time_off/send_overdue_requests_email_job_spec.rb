require 'rails_helper'

RSpec.describe TimeOff::SendOverdueRequestsEmailJob, type: :job do
  subject(:company) {FactoryGirl.create(:company, time_zone: "Pacific Time (US & Canada)")}
  subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year)}
  before { User.current = nick}
  describe 'Send Overdue requests email' do
    let!(:request) {create(:default_pto_request,  user: nick, pto_policy_id: nick.assigned_pto_policies.first.pto_policy_id)}
    
    it 'should send email for the request id passed' do
      expect{TimeOff::SendOverdueRequestsEmailJob.perform_now(request.id)}.to change{ CompanyEmail.all.count }.by(1)
    end

    it 'should not send email if id passed is nil' do
      expect{TimeOff::SendOverdueRequestsEmailJob.perform_now(nil)}.to change{ CompanyEmail.all.count }.by(0)
    end

    it 'should not send email if user manager is not present' do
      nick.update(manager_id: nil)
      expect{TimeOff::SendOverdueRequestsEmailJob.perform_now(request.id)}.to change{ CompanyEmail.all.count }.by(0)
    end
  end

end
