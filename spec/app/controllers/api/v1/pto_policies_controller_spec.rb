require 'rails_helper'

RSpec.describe Api::V1::PtoPoliciesController, type: :controller do
  let(:company) { create(:company_with_user, time_zone: "Pacific Time (US & Canada)") }
  let(:pto_policy) { create(:default_pto_policy, manager_approval: false, policy_type: 1, company: company) }
  let(:nick) { create(:nick, start_date: Date.today - 1.year) }

  before do
    allow(controller).to receive(:current_user).and_return(nick)
    allow(controller).to receive(:current_company).and_return(company)
  end

  before(:each) do
    nick.pto_policies << pto_policy
    @date = nick.company.time.to_date
    User.current = nick
  end

  describe '#filter_policies' do

    context 'filter selected for one year in past' do

      it 'returns pto_requests for one year in past and policy_type' do
        nick.update(start_date: 3.years.ago)
        pto_request = FactoryGirl.create(:default_pto_request, :denied_request_for_one_year_in_past, user_id: nick.id, pto_policy_id: pto_policy.id)
        pto_adjustment = FactoryGirl.create(:pto_adjustment, :applied_adjustment_past_year, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        res = get :filter_policies, params: { type: '1', year: @date.year() - 1, user_id: nick.id, reset: 'false', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(2)
        expect(response["history_entries"].first["id"]).to eq(pto_adjustment.id)
        expect(response["history_entries"].last["id"]).to eq(pto_request.id)
      end

    end

    context 'filter selected for current year or same type' do

      it 'returns pto_adjustments and pto_requests for current year' do
        pto_request = FactoryGirl.create(:default_pto_request, :denied_request_for_the_present_year, user_id: nick.id, pto_policy_id: pto_policy.id)
        if @date != @date.beginning_of_year
          pto_adjustment = FactoryGirl.create(:pto_adjustment, :applied_adjustment_of_past, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        else
          pto_adjustment = FactoryGirl.create(:pto_adjustment, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        end
        res = get :filter_policies, params: { type: '1', year: @date.year(), user_id: nick.id, reset: 'false', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(2)
        expect(response["history_entries"].first["id"]).to eq(pto_adjustment.id)
        expect(response["history_entries"].last["id"]).to eq(pto_request.id)
      end

      it 'returns pto_adjustments and pto_requests for current year and type nil' do
        pto_request = FactoryGirl.create(:default_pto_request, :denied_request_for_the_present_year, user_id: nick.id, pto_policy_id: pto_policy.id)
        if @date != @date.beginning_of_year
          pto_adjustment = FactoryGirl.create(:pto_adjustment, :applied_adjustment_of_past, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        else
          pto_adjustment = FactoryGirl.create(:pto_adjustment, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        end
        res = get :filter_policies, params: { type: nil, year: @date.year(), user_id: nick.id, reset: 'false', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(2)
        expect(response["history_entries"].first["id"]).to eq(pto_adjustment.id)
        expect(response["history_entries"].last["id"]).to eq(pto_request.id)
      end

      it 'returns pto_adjustments and pto_requests for policy_type and year nil' do
        pto_request = FactoryGirl.create(:default_pto_request, :denied_request_for_the_present_year, user_id: nick.id, pto_policy_id: pto_policy.id)
        if @date != @date.beginning_of_year
          pto_adjustment = FactoryGirl.create(:pto_adjustment, :applied_adjustment_of_past, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        else
          pto_adjustment = FactoryGirl.create(:pto_adjustment, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        end
        res = get :filter_policies, params: { type: 1, year: nil, user_id: nick.id, reset: 'false', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(2)
        expect(response["history_entries"].first["id"]).to eq(pto_adjustment.id)
        expect(response["history_entries"].last["id"]).to eq(pto_request.id)
      end

    end

    context 'filter not matching pto_requests or adjustments year' do

      it 'should not return any pto_request or pto_adjustment' do
        pto_request = FactoryGirl.create(:default_pto_request, :denied_request_for_the_present_year, user_id: nick.id, pto_policy_id: pto_policy.id)
        pto_adjustment = FactoryGirl.create(:pto_adjustment, :applied_adjustment_of_past, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        res = get :filter_policies, params: { type: '1', year: @date.year() + 5, user_id: nick.id, reset: 'false', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(0)
      end

    end

    context 'resetting filters' do

      it 'returns filtered data for the current year' do
        nick.update(start_date: 3.years.ago)
        pto_request_present_year = FactoryGirl.create(:default_pto_request, :denied_request_for_the_present_year, user_id: nick.id, pto_policy_id: pto_policy.id)
        pto_request_next_year = FactoryGirl.create(:default_pto_request, :denied_request_for_one_year_in_past, user_id: nick.id, pto_policy_id: pto_policy.id)
        pto_adjustment = FactoryGirl.create(:pto_adjustment, :applied_adjustment_of_same_year, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        res = get :filter_policies, params: { type: '1', year: @date.year() + 5, user_id: nick.id, reset: 'true', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(2)
        expect(response["history_entries"].first["id"]).to eq(pto_adjustment.id)
        expect(response["history_entries"].last["id"]).to eq(pto_request_present_year.id)
      end

    end

    context 'returns data' do
      it 'for user_id sent in params for pto_request' do
        pto_request_present_year = FactoryGirl.create(:default_pto_request, :denied_request_for_the_present_year, user_id: nick.id, pto_policy_id: pto_policy.id)
        res = get :filter_policies, params: { type: '1', year: @date.year(), user_id: nick.id, reset: 'false', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(1)
        expect(response["history_entries"].first["user_id"]).to eq(nick.id)
      end
    end

    context 'does not return data' do
      it 'for different user sent in params' do
        peter = create(:peter)
        pto_adjustment = FactoryGirl.create(:pto_adjustment, :applied_adjustment_of_same_year, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, creator_id: company.users.first.id)
        res = get :filter_policies, params: { type: '1', year: @date.year(), user_id: peter.id, reset: 'false', operation_type: "Usage" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(0)
      end
    end

    context 'Accrual data' do
      it 'should return the accrual logs if reset is true' do
        audit = FactoryGirl.create(:pto_balance_audit_log, user_id: nick.id, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, description: 'Accrual', balance_updated_at: @date)
        res = get :filter_policies, params: { type: '1', year: @date.year(), user_id: nick.id, reset: 'true', operation_type: "Accrual" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(1)
      end

      it 'should return the accrual logs if type is null' do
        audit = FactoryGirl.create(:pto_balance_audit_log, user_id: nick.id, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, description: 'Accrual', balance_updated_at: @date)
        res = get :filter_policies, params: { type: nil, year: @date.year(), user_id: nick.id, reset: 'false', operation_type: "Accrual" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(1)
      end

      it 'should return the accrual logs if year is null' do
        audit = FactoryGirl.create(:pto_balance_audit_log, user_id: nick.id, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, description: 'Accrual', balance_updated_at: @date)
        res = get :filter_policies, params: { type: '1', year: nil, user_id: nick.id, reset: 'false', operation_type: "Accrual" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(1)
      end

      it 'should return the accrual logs if type and year are same' do
        audit = FactoryGirl.create(:pto_balance_audit_log, user_id: nick.id, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, description: 'Accrual', balance_updated_at: @date)
        res = get :filter_policies, params: { type: '1', year: @date.year(), user_id: nick.id, reset: 'false', operation_type: "Accrual" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(1)
      end

      it 'should not return the accrual logs if not present' do
        res = get :filter_policies, params: { type: '1', year: @date.year(), user_id: nick.id, reset: 'true', operation_type: "Accrual" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(0)
      end

      it 'should not return the accrual logs if not of same year' do
        audit = FactoryGirl.create(:pto_balance_audit_log, user_id: nick.id, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, description: 'Accrual', balance_updated_at: @date)
        res = get :filter_policies, params: { type: '1', year: @date.year() + 1.year, user_id: nick.id, reset: 'false', operation_type: "Accrual" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(0)
      end

      it 'should not return the accrual logs if type not same' do
        audit = FactoryGirl.create(:pto_balance_audit_log, user_id: nick.id, assigned_pto_policy_id: nick.assigned_pto_policies.first.id, description: 'Accrual', balance_updated_at: @date)
        res = get :filter_policies, params: { type: 2, year: @date.year() + 1.year, user_id: nick.id, reset: 'false', operation_type: "Accrual" }, format: :json
        response = JSON.parse res.body
        expect(response["history_entries"].size).to eq(0)
      end
    end

  end

  describe 'policy_eoy_balance' do
    context 'failure' do
      it 'should not return policy_eoy_balance if current_company not present' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :policy_eoy_balance, params: {id: pto_policy.id, user_id: nick.id}, format: :json
        expect(response.status).to eq(404)
      end

      it 'should not return policy_eoy_balance if user_id not present' do
        get :policy_eoy_balance, params: {id: pto_policy.id}, format: :json
        expect(JSON.parse(response.body)['eoy_balance']).to eq(nil)
      end

      it 'should not return policy_eoy_balance if policy is unlimited' do
        pto_policy.update(unlimited_policy: true)
        get :policy_eoy_balance, params: {id: pto_policy.id, user_id: nick.id}, format: :json
        expect(JSON.parse(response.body)['eoy_balance']).to eq(nil)
      end

      it 'should not return policy_eoy_balance if policy not present' do
        get :policy_eoy_balance, params: {id: 100, user_id: nick.id }, format: :json
        expect(JSON.parse(response.body)['eoy_balance']).to eq(nil)
      end
    end

    context 'success' do
      it 'should return policy_eoy_balance if policy is limited' do
        get :policy_eoy_balance, params: {id: pto_policy.id, user_id: nick.id}, format: :json
        expect(JSON.parse(response.body)['eoy_balance']).to_not eq(nil)
      end
    end

  end

end
