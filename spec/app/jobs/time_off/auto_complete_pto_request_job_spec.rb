require 'rails_helper'
RSpec.describe TimeOff::AutoCompletePtoRequestJob, type: :job do
  let(:company) { create(:company, enabled_time_off: true) }
  let(:manager) { create(:user, company: company, email: "fan@fan.com", personal_email: "sand@sand.com") }
  let(:user) { create(:user, company: company, start_date: Date.today - 1.year, manager: manager) }
  
  before do
    User.current = user
  end

  describe 'Request auto approved' do
    let(:pto_policy){ create(:default_pto_policy, days_to_wait_until_auto_actionable: rand(1..7), auto_approval: true, company: company) }
    let(:pto_request) { create(:pto_request, pto_policy: pto_policy, user: user, begin_date: company.time.to_date, end_date: (company.time + 2.days).to_date, partial_day_included: false)}
    
    it 'auto_approves pto request after the waiting period' do
      pto_request.update_column(:submission_date, pto_policy.days_to_wait_until_auto_actionable.days.ago) 
      TimeOff::AutoCompletePtoRequestJob.perform_now
      expect(pto_request.reload.status).to eq("approved")
    end
  end

  describe 'Request auto deny' do
    let(:pto_policy){ create(:default_pto_policy, days_to_wait_until_auto_actionable: rand(1..7), auto_approval: false, company: company) }
    let(:pto_request) { create(:pto_request, pto_policy: pto_policy, user: user, begin_date: company.time.to_date, end_date: (company.time + 2.days).to_date, partial_day_included: false)}
    
    it 'auto_denies pto request after the waiting period' do
      pto_request.update_column(:submission_date, pto_policy.days_to_wait_until_auto_actionable.days.ago) 
      TimeOff::AutoCompletePtoRequestJob.perform_now
      expect(pto_request.reload.status).to eq("denied")
    end
  end

  describe 'Policy with manager false' do
    let(:pto_policy){ create(:default_pto_policy, manager_approval: false, days_to_wait_until_auto_actionable: rand(1..7), auto_approval: false, company: company) }
    let(:pto_request) { create(:pto_request, pto_policy: pto_policy, user: user, begin_date: company.time.to_date, end_date: (company.time + 2.days).to_date, partial_day_included: false)}
    
    it 'should not perform any action' do
      pto_request.update_column(:submission_date, pto_policy.days_to_wait_until_auto_actionable.days.ago) 
      TimeOff::AutoCompletePtoRequestJob.perform_now
      expect(pto_request.reload.status).to eq("pending")
    end
  end

  describe 'Policy with request not in pending state' do
    let(:pto_policy){ create(:default_pto_policy, days_to_wait_until_auto_actionable: rand(1..7), auto_approval: false, company: company) }
    let(:pto_request) { create(:pto_request, pto_policy: pto_policy, user: user, begin_date: company.time.to_date, end_date: (company.time + 2.days).to_date, partial_day_included: false, status: 3)}
    
    it 'should not perform any action' do
      pto_request.update_column(:submission_date, pto_policy.days_to_wait_until_auto_actionable.days.ago) 
      status = pto_request.status
      TimeOff::AutoCompletePtoRequestJob.perform_now
      expect(pto_request.reload.status).to eq(status)
    end
  end

  describe 'Policy with multiple approval' do
    let(:pto_policy){ create(:default_pto_policy, days_to_wait_until_auto_actionable: rand(1..7), manager_approval: true, company: company) }
    let(:pto_request) { create(:pto_request, pto_policy: pto_policy, user: user, begin_date: company.time.to_date, end_date: (company.time + 2.days).to_date, partial_day_included: false)}
    
    before do
      pto_policy.approval_chains << FactoryGirl.create(:approval_chain, approval_type: ApprovalChain.approval_types[:permission], approval_ids: ["all"])
    end
    
    it 'should not perform any action' do
      pto_request.update_column(:submission_date, pto_policy.days_to_wait_until_auto_actionable.days.ago) 
      TimeOff::AutoCompletePtoRequestJob.perform_now
      expect(pto_request.reload.status).to eq("approved")
    end
  end

end