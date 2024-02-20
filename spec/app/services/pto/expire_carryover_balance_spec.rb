require 'rails_helper'

RSpec.describe Pto::ExpireCarryoverBalance do

  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:policy) { create(:default_pto_policy, :policy_with_expiry_carryover, company: company, carryover_amount_expiry_date: company.time.to_date -  1.day)}
  let(:assigned_policy) { create(:assigned_pto_policy, user: user, pto_policy: policy, balance: 20, carryover_balance: 20)}
  let(:pto_request) { create(:pto_request, user: user, pto_policy: policy, partial_day_included: false, status: 0, begin_date: user.company.time.to_date, end_date: ( user.company.time.to_date + 2.days), balance_hours: 24) }

  it "sets positive carryover balance to zero on expiry job" do
    assigned_policy
    Pto::ExpireCarryoverBalance.new.perform(company.id)
    assigned_policy.reload
    expect(assigned_policy.carryover_balance).to eq(0)
  end

  it "stays negative carryover balance unchanged on expiry job" do
    assigned_policy.update(carryover_balance: -10)
    Pto::ExpireCarryoverBalance.new.perform(company.id)
    assigned_policy.reload
    expect(assigned_policy.carryover_balance).to eq(-10)
  end
end
