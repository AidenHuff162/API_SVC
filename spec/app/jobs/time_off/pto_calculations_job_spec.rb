require 'rails_helper'

RSpec.describe TimeOff::PtoCalculationsJob, type: :job do
  subject(:company) {FactoryGirl.create(:company, enabled_time_off: true, time_zone: "UTC")}
  subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy, :with_expiry_and_renewal_today, start_date: Time.now.utc() + 1.day, company: company, start_date: Date.today - 1.year)}
  subject(:peter) {FactoryGirl.create(:user_with_manager_and_policy, :with_policies_accrual_at_end_of_period, email: "slow@slow.com", personal_email: "fast@fast.com", start_date: Time.now.utc() + 1.day, company: company)}
  subject(:pto_adjustment) {create(:pto_adjustment, hours: 8, assigned_pto_policy: nick.assigned_pto_policies.first, creator: nick,  effective_date: company.time)}
  subject(:pto_request) {create(:default_pto_request, user: nick, pto_policy: nick.pto_policies.first, begin_date: company.time, end_date: company.time, balance_hours: 8)}
  before do
    User.current = nick
    
    peter.assigned_pto_policies.first.update_columns(first_accrual_happening_date: Time.now.utc(), start_of_accrual_period: Time.now.utc())
    
    pto_adjustment.update_columns(is_applied: false)
    pto_request.update_columns(balance_deducted: false)
    pto_request.pto_policy.update(working_days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    @assigned_pto_policy = nick.assigned_pto_policies.first
    @assigned_pto_policy.update_columns(first_accrual_happening_date: Time.now.utc(), start_of_accrual_period: Time.now.utc())
    @assigned_pto_policy.update_columns(carryover_balance: 12, balance: 10, balance_updated_at: nil, is_balance_calculated_before: false)
  end
  
  describe 'at start of period' do
    before do
      TimeOff::PtoCalculationsJob.perform_now([company.id], [])
      @assigned_pto_policy.reload
    end

    it 'should expire, renew, apply adjustment, accrue and deduct pto balance ' do
      expect(@assigned_pto_policy.is_balance_calculated_before).to eq(true)
      expect(@assigned_pto_policy.balance > pto_adjustment.hours).to eq(true)
      expect(@assigned_pto_policy.carryover_balance).to eq(2)
      expect(pto_request.reload.balance_deducted).to eq(true)
      expect(pto_adjustment.reload.is_applied).to eq(true)
    end

     it 'should not accrue balance for policies at_end_of_period ' do
      expect(peter.assigned_pto_policies.first.is_balance_calculated_before).to eq(false)
    end

  end

  describe 'at end of period' do
    before do
      peter.assigned_pto_policies.first.update_columns(carryover_balance: 0, balance: 0, balance_updated_at: nil, is_balance_calculated_before: false)
      TimeOff::PtoCalculationsJob.perform_now([], [company.id])
    end

    it 'should accrue balance only ' do
      expect(peter.assigned_pto_policies.first.is_balance_calculated_before).to eq(true)
      expect(peter.assigned_pto_policies.first.balance > 0).to eq(true)
    end

    it 'should keep assigned_pto_policy unchanged' do
      expect(nick.assigned_pto_policies.first.is_balance_calculated_before).to eq(false)
      expect(@assigned_pto_policy.balance ).to eq(10)
      expect(@assigned_pto_policy.carryover_balance).to eq(12)
      expect(pto_request.reload.balance_deducted).to eq(false)
      expect(pto_adjustment.reload.is_applied).to eq(false)
    end
  end

end
