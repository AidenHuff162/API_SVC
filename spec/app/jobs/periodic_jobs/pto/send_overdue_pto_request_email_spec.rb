require 'rails_helper'
RSpec.describe PeriodicJobs::Pto::SendOverduePtoRequestEmail, type: :job do
  
  before do
    time = Time.now.utc()
    Time.stub(:now) {time}
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
  end
  describe 'sending overdue request email' do
    let(:company) {create(:company, enabled_time_off: true, time_zone: "UTC")}
    subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year)}
    before {User.current = nick}
    
    context 'Future overdue request' do
      let!(:pto_request) {create(:default_pto_request, user: nick, begin_date: company.time + 2.days, end_date: company.time + 2.days,  pto_policy: nick.pto_policies.first, status: "pending", created_at: 6.days.ago)}

      it 'should schedule one job for the request' do
        expect{PeriodicJobs::Pto::SendOverduePtoRequestEmail.new.perform}.to change{ActiveJob::Base.queue_adapter.enqueued_jobs.count}.by(1)
      end
    end

    context 'past overdue request' do
      let!(:pto_request) {create(:default_pto_request, user: nick, begin_date: company.time - 2.days, end_date: company.time - 2.days,  pto_policy: nick.pto_policies.first, status: "pending", created_at: 6.days.ago)}

      it 'should not schedule job for the request' do
        expect{PeriodicJobs::Pto::SendOverduePtoRequestEmail.new.perform}.to change{ActiveJob::Base.queue_adapter.enqueued_jobs.count}.by(0)
      end
    end

    context 'no overdue request' do
      let!(:pto_request) {create(:default_pto_request, user: nick, begin_date: company.time + 2.days, end_date: company.time + 2.days,  pto_policy: nick.pto_policies.first, status: "pending", created_at: 3.days.ago)}

      it 'should not schedule job for the request' do
        expect{PeriodicJobs::Pto::SendOverduePtoRequestEmail.new.perform}.to change{ActiveJob::Base.queue_adapter.enqueued_jobs.count}.by(0)
      end
    end


    context 'multiple future overdue request' do
      let!(:pto_request) {create(:default_pto_request, user: nick, begin_date: company.time + 2.days, end_date: company.time + 2.days,  pto_policy: nick.pto_policies.first, status: "pending", created_at: 6.days.ago)}
      let!(:pto_request2) {create(:default_pto_request, user: nick, begin_date: company.time + 3.days, end_date: company.time + 3.days,  pto_policy: nick.pto_policies.first, status: "pending", created_at: 6.days.ago)}

      it 'should schedule multiple jobs for the requests' do
        expect{PeriodicJobs::Pto::SendOverduePtoRequestEmail.new.perform}.to change{ActiveJob::Base.queue_adapter.enqueued_jobs.count}.by(2)
      end
    end

    context 'approved request' do
      let!(:pto_request) {create(:default_pto_request, user: nick, begin_date: company.time + 2.days, end_date: company.time + 2.days,  pto_policy: nick.pto_policies.first, status: "approved", created_at: 6.days.ago)}

      it 'should not schedule job for approved request' do
        expect{PeriodicJobs::Pto::SendOverduePtoRequestEmail.new.perform}.to change{ActiveJob::Base.queue_adapter.enqueued_jobs.count}.by(0)
      end
    end


  end
end
