require 'rails_helper'

RSpec.describe Pto::MakePtoAdjustments do
  subject(:company) {FactoryGirl.create(:company, time_zone: "Pacific Time (US & Canada)")}
  subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy, company: company)}

  describe 'Pto adjustment create' do
    let!(:pto_adjustment) {create(:pto_adjustment, :future_adjustment, creator: nick, hours: 10, assigned_pto_policy: nick.assigned_pto_policies.first, operation: 1)}
    context 'Job should not add balance of future adjustments' do
      before do
        @assigned_pto_policy = nick.assigned_pto_policies.first
        @balance = @assigned_pto_policy.balance
        Pto::MakePtoAdjustments.new.perform(company.id)
        @assigned_pto_policy.reload
        pto_adjustment.reload
      end
      it 'should not update balance' do
        expect(@assigned_pto_policy.balance).not_to eq(@balance + pto_adjustment.hours)
      end
      it 'should not set is_applied true' do
        expect(pto_adjustment.is_applied).not_to eq(true)
      end
    end

    context 'Job should add balance of past or today date adjustments' do
      before do
        @assigned_pto_policy = nick.assigned_pto_policies.first
        @balance = @assigned_pto_policy.balance
        pto_adjustment.update_column(:effective_date, DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date)
        Pto::MakePtoAdjustments.new.perform(company.id)
        @assigned_pto_policy.reload
        pto_adjustment.reload
      end
      it 'should update balance' do
        expect(@assigned_pto_policy.balance).to eq(@balance + pto_adjustment.hours)
      end
      it 'should not set is_applied true' do
        expect(pto_adjustment.is_applied).to eq(true)
      end
    end

  end
end
