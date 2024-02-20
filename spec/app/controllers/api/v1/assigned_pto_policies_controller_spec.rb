require 'rails_helper'

RSpec.describe Api::V1::AssignedPtoPoliciesController, type: :controller do

  let(:user) { create(:user_with_manager_and_policy) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe 'Estimating balance' do
    it "It should return balance and logs" do
      policy_id = user.assigned_pto_policies.first.pto_policy_id
      response = get :estimated_balance, params: { employee_id: user.id, pto_policy_id: policy_id, estimate_date: (Date.today + 15.days) }, format: :json 
      response = JSON.parse response.body
      expect(response["estimated_balance"]).to be_present
      expect(response["audit_logs"]).to be_present
    end

    it "it should return assigned_pto_policy balance and logs for past dates" do
      assigned_pto_policy = user.assigned_pto_policies.first
      policy_id = assigned_pto_policy.pto_policy_id
      response = get :estimated_balance, params: { employee_id: user.id, pto_policy_id: policy_id, estimate_date: (Date.today - 1.days) }, format: :json 
      response = JSON.parse response.body
      expect(response["estimated_balance"]).to eq(assigned_pto_policy.balance)
      expect(response["audit_logs"].count).to eq(assigned_pto_policy.pto_balance_audit_logs.count)
    end
  end
end
