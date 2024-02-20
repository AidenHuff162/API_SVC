require 'rails_helper'

RSpec.describe Api::V1::Admin::PtoPoliciesController, type: :controller do
  let(:company) { create(:company, subdomain: 'spaceship', enabled_calendar: true) }
  let(:company2) { create(:company, time_zone: "Pacific Time (US & Canada)") }
  let(:location) {create(:location, company: company)}
  let(:location2) {create(:location, company: company)}
  let(:sarah) { create(:sarah, company: company) }
  let!(:pto_policy) { create(:default_pto_policy, company: company) }


  before do
    allow(controller).to receive(:current_user).and_return(sarah)
    allow(controller).to receive(:current_company).and_return(sarah.company)
  end

  describe 'authorizations' do
    let(:peter) { create(:user, email: "slow@slow.com", company: company2) }
    it 'user of (different) company cannot manage pto_policy' do
      ability = Ability.new(peter)
      assert ability.cannot?(:manage, pto_policy)
    end

    it 'user of same company can manage pto_policy' do
      ability = Ability.new(sarah)
      assert ability.can?(:manage, pto_policy)
    end
  end

  describe '#index' do
    it 'should return the policies of current company' do
      res = get :index, format: :json
      res = JSON.parse res.body
      expect(res.count).to eq(1)
    end

    it 'should not return the policies of other company' do
      allow(controller).to receive(:current_company).and_return(company2)
      res = get :index, format: :json
      expect(res.status).to eq(403)
    end

    context 'location filter' do
      let!(:pto_policy_3) { create(:default_pto_policy, :policy_for_some_employees, policy_type: 1, company: company, filter_policy_by:  {location: [location2.id], teams: ["all"], employee_status: ["all"]}) }
      let!(:pto_policy_2) { create(:default_pto_policy, :policy_for_some_employees, policy_type: 0, company: company, filter_policy_by:  {location: [location.id], teams: ["all"], employee_status: ["all"]}) }
      it 'should return the policy with specific location' do
        res = get :index, params: { location: location.id.to_s }, format: :json
        res = JSON.parse res.body
        expect((res.map { |p| p["id"]}).include?(pto_policy_2.id)).to eq(true)
      end

      it 'should return the policy for all employes' do
        res = get :index, params: { meta: { location_id: location.id.to_s}.to_json }, format: :json
        res = JSON.parse res.body
        expect((res.map { |p| p["id"]}).include?(pto_policy.id)).to eq(true)
      end

      it 'should not return the policy with other location' do
        res = get :index, params: { meta: { location_id: location.id.to_s }.to_json }, format: :json
        res = JSON.parse res.body
        expect((res.map { |p| p["id"]}).include?(pto_policy_3.id)).to eq(false)
      end

      it 'should return the policy with specific type' do
        res = get :index, params: { policy_type: 0 }, format: :json
        res = JSON.parse res.body
        expect((res.map { |p| p["id"]}).include?(pto_policy_2.id)).to eq(true)
      end

      it 'should not return the policy with other type' do
        res = get :index, params: { meta: { location_id: location.id.to_s}.to_json }, format: :json
        res = JSON.parse res.body
        expect((res.map { |p| p["id"]}).include?(pto_policy_3.id)).to eq(false)
      end
    end
  end


  describe '#pto_policy_paginated' do
    it 'should return data base on paginated' do
      res = get :pto_policy_paginated, params: { start: 0 , length:1}, format: :json
      res = JSON.parse res.body
      expect(res["recordsTotal"]).to eq(1)
    end
  end

  describe '#enabled_policies' do
    it 'should return the enabled_policies of current company' do
      res = get :enabled_policies,  format: :json
      res = JSON.parse res.body
      expect(res.count).to eq(1)
    end

    it 'should not return the disabled of current company' do
      pto_policy.update(is_enabled: false)
      res = get :enabled_policies,  format: :json
      res = JSON.parse res.body
      expect((res.map { |p| p["id"]}).include?(pto_policy.id)).to eq(false)
    end
  end

  describe '#create' do
    let(:nick) { create(:nick, company: company) }
    let(:sam) { create(:peter, company: company) }
    before do
      @params = {name: "New Vacation Policy", icon: "icon-heart", for_all_employees: true, policy_type: "vacation", filter_policy_by: "{\"location\":[\"all\"],\"teams\":[\"all\"],\"employee_status\":[\"all\"]}", unlimited_policy: false, accrual_rate_amount: 20, accrual_rate_unit: "hours", rate_acquisition_period: "year", accrual_frequency: "weekly", max_accrual_amount: nil, allocate_accruals_at: "end", start_of_accrual_period: "hire_date", accrual_renewal_time: "1st_of_january", accrual_renewal_date: "2019-01-01", first_accrual_method: "prorated_amount", carry_over_unused_timeoff: true, has_maximum_carry_over_amount: false, can_obtain_negative_balance: true, carry_over_negative_balance: true, manager_approval: false, auto_approval: true, tracking_unit: "hourly_policy", expire_unused_carryover_balance: false, working_hours: 8, half_day_enabled: false, days_to_wait_until_auto_actionable: 7, working_days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], format: :json}
    end
    it 'should allow user to create policy' do
      post :create, params: @params
      expect(response.status).to eq(201)
    end

    it 'should not  allow user to create policy for other company' do
      allow(controller).to receive(:current_company).and_return(company2)
      post :create, params: @params
      expect(response.status).to eq(403)
    end

    it 'should not  allow employee to create policy ' do
      allow(controller).to receive(:current_user).and_return(nick)
      post :create, params: @params
      expect(response.status).to eq(403)
    end

    it 'should not  allow user to create policy with missing params' do
      post :create, params: @params.except!(:name)
      expect(response.status).to eq(422)
    end
    context 'admin' do
      before do
        allow(controller).to receive(:current_user).and_return(sam)
      end
      it 'should not  allow admin to create policy with permission no_access' do
        post :create, params: @params
        expect(response.status).to eq(403)
      end

      it 'should allow admin to create policy with permission view_and_edit' do
        role = sam.user_role
        role["permissions"]["admin_visibility"]["time_off"] = "view_and_edit"
        role.save!
        allow(controller).to receive(:current_user).and_return(sam)
        post :create, params: @params
        expect(response.status).to eq(201)
      end

      it 'should not allow admin to create policy with permission view_only' do
        role = sam.user_role
        role["permissions"]["admin_visibility"]["time_off"] = "view_only"
        role.save!
        allow(controller).to receive(:current_user).and_return(sam)
        post :create, params: @params
        expect(response.status).to eq(403)
      end
    end
  end

  describe '#enable_disable_policy' do
    it 'should disable the policy' do
      post :enable_disable_policy, params: { id: pto_policy.id, is_enabled: false }, format: :json
      expect(pto_policy.reload.is_enabled).to eq(false)
    end

    it 'should e enable the policy' do
      pto_policy.update(is_enabled: false)
      post :enable_disable_policy, params: { id: pto_policy.id, is_enabled: true }, format: :json
      expect(pto_policy.reload.is_enabled).to eq(true)
    end
  end

  describe '#show' do
    it 'should return the policy' do
      get :show, params: { id: pto_policy.id }, format: :json
      expect(JSON.parse(response.body)["id"]).to eq(pto_policy.id)
    end

    it 'should not return the policy of other company' do
      allow(controller).to receive(:current_company).and_return(company2)
      get :show, params: { id: pto_policy.id }, format: :json
      expect(response.status).to eq(403)
    end
  end

  describe '#update' do
    it 'should allow user to update the policy' do
      put :update, params: { id: pto_policy.id, name: 'fast' }, format: :json
      expect(pto_policy.reload.name).to eq('fast')
    end
    context 'multiple attributes' do
      before do
        put :update, params: { id: pto_policy.id, name: 'fast', manager_approval: false }, format: :json
      end
      it 'should allow update name' do
        expect(pto_policy.reload.name).to eq('fast')
      end

      it 'should allow update manager_approval' do
        expect(pto_policy.reload.manager_approval).to eq(false)
      end
    end

    it 'should not allow user to update the policy of other company' do
      allow(controller).to receive(:current_company).and_return(company2)
      put :update, params: { id: pto_policy.id, name: 'fast' }, format: :json
      expect(response.status).to eq(403)
    end
  end

  describe '#destroy' do

    before do
      @pto_policy = pto_policy
      @user = sarah
      @user.update(start_date: Date.today - 1.year)
      @company = sarah.company
      User.current = @user 
      assigned_pto_policy = create(:assigned_pto_policy, user: @user, pto_policy: @pto_policy, balance: 20)
      create(:default_pto_request, user: @user, pto_policy: @pto_policy, status: 0)
      create(:unassigned_pto_policy, user: @user, pto_policy: @pto_policy, starting_balance: 20, effective_date: @pto_policy.company.time.to_date)
      create(:pto_adjustment, creator: @user, hours: 10, assigned_pto_policy: assigned_pto_policy, operation: 1, effective_date: @pto_policy.company.time.to_date)
      create(:policy_tenureship, pto_policy: @pto_policy)
    end

    it 'removes policy and its associations' do
      Sidekiq::Testing.inline! do
        delete :destroy, params: { id: @pto_policy.id }, format: :json
        expect(PtoAdjustment.all.size).to eq(0)
        expect(AssignedPtoPolicy.all.size).to eq(0)
        expect(UnassignedPtoPolicy.all.size).to eq(0)
        expect(PtoRequest.all.size).to eq(0)
        expect(PolicyTenureship.all.size).to eq(0)
        expect(CalendarEvent.where(eventable_type: 'PtoRequest').size).to eq(0)
        expect(@user.reload.deleted_at).to eq(nil)
        expect(@company.reload.deleted_at).to eq(nil)
      end
    end
  end

end
