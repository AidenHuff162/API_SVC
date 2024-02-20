require 'rails_helper'

RSpec.describe Api::V1::PtoAdjustmentsController, type: :controller do
  let(:company) { create(:company, enabled_time_off: true, subdomain: 'pto-company') }
  let(:user) { create(:user, company: company) }
  let(:nick) { create(:nick, company: company) }

  before do
    allow(controller).to receive(:current_company).and_return(company)
    @date = company.time.to_date
    Sidekiq::Testing.inline! do
      FactoryGirl.create(:default_pto_policy, company: company)
    end
  end


  describe 'authorisation' do
    let(:other_employee) { create(:nick, company: company, email: "spacer@facer.com", personal_email: "specified@faced.com") }
    let(:company2) { create(:company, enabled_time_off: true) }
    let(:user2) { create(:user, company: company2) }

    before do
      @pto_adjustment = FactoryGirl.create(:pto_adjustment, creator: user, hours: 10, assigned_pto_policy: nick.assigned_pto_policies.first, operation: 1)
    end

    context 'user of company' do
      it 'admin can manage pto adjustment of company' do
        ability = Ability.new(user)
        assert ability.can?(:manage, @pto_adjustment)
      end

      it 'nick can read pto adjustment of company' do
        ability = Ability.new(nick)
        assert ability.can?(:read, @pto_adjustment)
      end

      it 'nick cannot manage pto adjustment of company' do
        ability = Ability.new(nick)
        assert ability.cannot?(:manage, @pto_adjustment)
      end

      it 'manager can manage pto adjustment of company' do
        ability = Ability.new(nick.manager)
        assert ability.can?(:manage, @pto_adjustment)
      end

      it 'other employee cannot manage pto adjustment of company' do
        ability = Ability.new(other_employee)
        assert ability.cannot?(:manage, @pto_adjustment)
      end

      it 'other employee cannot read pto adjustment of company' do
        ability = Ability.new(other_employee)
        assert ability.cannot?(:read, @pto_adjustment)
      end

      it 'other employee manager cannot manage pto adjustment of company' do
        ability = Ability.new(other_employee.manager)
        assert ability.cannot?(:manage, @pto_adjustment)
      end
    end

    context 'user of company2' do
      it 'cannot manage pto adjustment of company' do
        ability = Ability.new(user2)
        assert ability.cannot?(:manage, @pto_adjustment)
      end
    end

  end

	describe 'Deletion' do
    subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy)}
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_company).and_return(nick.company)
    end

	 	context "on deletion" do
  	  context 'addition adjusntment' do
        before do
          pto_adjustment_addition = FactoryGirl.create(:pto_adjustment, creator: user, hours: 10, assigned_pto_policy: nick.assigned_pto_policies.first, operation: 1)
          delete :destroy, params: { id: pto_adjustment_addition.id, employee_id: nick.id, pto_policy_id: nick.pto_policies.first.id }, as: :json
        end
  	    it 'should deduct hours from assigned pto policy' do
  	      expect(nick.assigned_pto_policies.first.balance).to eq(0)
  	    end
        it 'should delete pto_adjustment' do
          expect(nick.assigned_pto_policies.first.pto_adjustments.size).to eq(0)
        end
      end

      context 'subtraction adjusntment' do
        before do
          pto_adjustment_subtraction = FactoryGirl.create(:pto_adjustment, creator: user, hours: 10, assigned_pto_policy: nick.assigned_pto_policies.first, operation: 2)
          delete :destroy, params: { id: pto_adjustment_subtraction.id, employee_id: nick.id, pto_policy_id: nick.pto_policies.first.id }, as: :json
        end
        it 'should deduct hours from assigned pto policy' do
          expect(nick.assigned_pto_policies.first.balance).to eq(0)
        end
        it 'should delete pto_adjustment' do
          expect(nick.assigned_pto_policies.first.pto_adjustments.size).to eq(0)
        end
      end
	  end
	end

  describe '#create' do
    let(:new_user) { create(:user, state: :active, current_stage: :registered, start_date: Date.today, company: company)}
    let(:employee) {create(:nick, :manager_with_role, company:company)}
    let(:admin_user) {create(:peter, company:company)}

    context 'Super admin ' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end
      it 'should be able to create own adjustment' do
        res = post :create, params: { hours: 10, pto_policy_id: user.pto_policies.first.id, employee_id: user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(user.assigned_pto_policies.first.pto_adjustments.size).to eq(1)
      end

      it 'should be able to create others adjustment' do
        res = post :create, params: { creator: user, hours: 10, pto_policy_id: new_user.pto_policies.first.id, employee_id: new_user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(new_user.assigned_pto_policies.first.pto_adjustments.size).to eq(1)
      end

    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should be able to create own adjustment with view_and_edit permissions' do
        res = post :create, params: { hours: 10, pto_policy_id: admin_user.pto_policies.first.id, employee_id: admin_user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(admin_user.assigned_pto_policies.first.pto_adjustments.size).to eq(1)
      end

      it 'should not be able to create own adjustment with view_only permissions' do
        admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "view_only"
        admin_user.save!
        res = post :create, params: { hours: 10, pto_policy_id: admin_user.pto_policies.first.id, employee_id: admin_user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(admin_user.assigned_pto_policies.first.pto_adjustments.size).to eq(0)
      end

      it 'should not be able to create own adjustment with no_access permissions' do
        admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "no_access"
        admin_user.save!
        res = post :create, params: { hours: 10, pto_policy_id: admin_user.pto_policies.first.id, employee_id: admin_user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(admin_user.assigned_pto_policies.first.pto_adjustments.size).to eq(0)
      end

      it 'should not be able to create others adjustment with platform visibility no_access' do
        res = post :create, params: { hours: 10, pto_policy_id: admin_user.pto_policies.first.id, employee_id: new_user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(res.status).to eq(204)
      end

      it 'should not be able to create others adjustment with platform visibility view_only' do
        admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_only"
        admin_user.save!
        res = post :create, params: { hours: 10, pto_policy_id: admin_user.pto_policies.first.id, employee_id: new_user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(res.status).to eq(204)
      end

      it 'should be able to create others adjustment with platform visibility view_and_edit' do
        admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_and_edit"
        admin_user.save!
        res = post :create, params: { hours: 10, pto_policy_id: admin_user.pto_policies.first.id, employee_id: new_user.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(new_user.assigned_pto_policies.first.pto_adjustments.size).to eq(1)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it 'should not be able to create own adjustment' do
        res = post :create, params: { hours: 10, pto_policy_id: employee.pto_policies.first.id, employee_id: employee.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(res.status).to eq(204)
      end
    end

    context 'Manager' do
      before do
        @manager = employee.manager
        allow(controller).to receive(:current_user).and_return(@manager)
      end

      it 'should not be able to create own adjustment' do
        res = post :create, params: { hours: 10, pto_policy_id: @manager.pto_policies.first.id, employee_id: @manager.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(res.status).to eq(204)
      end

      it 'should be able to create employee adjustment' do
        res = post :create, params: { hours: 10, pto_policy_id: employee.pto_policies.first.id, employee_id: employee.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(employee.assigned_pto_policies.first.pto_adjustments.size).to eq(1)
      end

      it 'should not be able to create employee adjustment with platform visibility view_only' do
        employee.manager.user_role.permissions["platform_visibility"]["time_off"] = 'view_only'
        res = post :create, params: { hours: 10, pto_policy_id: employee.pto_policies.first.id, employee_id: employee.id, operation: 1, description: "hello", effective_date: @date }, as: :json
        expect(res.status).to eq(204)
      end
    end
  end

  describe 'index' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    it 'should return adjustment with effective of date present' do
      pto_adjustment = FactoryGirl.create(:pto_adjustment, creator: user, hours: 10, assigned_pto_policy: user.assigned_pto_policies.first, operation: 1, effective_date: @date )
      res = get :index, params: { user_id: user.id }, as: :json
      res = JSON.parse res.body
      expect(res.size).to eq(1)
    end

    it 'should return adjustment with effective of date past' do
      pto_adjustment = FactoryGirl.create(:pto_adjustment, creator: user, hours: 10, assigned_pto_policy: user.assigned_pto_policies.first, operation: 1, effective_date: (@date - 2.days).year != @date.year ? @date : (@date - 2.days))
      res = get :index, params: { user_id: user.id }, format: :json
      res = JSON.parse res.body
      expect(res.size).to eq(1)
    end

    it 'should not return adjustment with effective of date past year' do
      pto_adjustment = FactoryGirl.create(:pto_adjustment, creator: user, hours: 10, assigned_pto_policy: user.assigned_pto_policies.first, operation: 1, effective_date: @date - 365.days)
      res = get :index, params: { user_id: user.id }, as: :json
      res = JSON.parse res.body
      expect(res.size).to eq(0)
    end

    it 'should not return adjustment with effective of date future ' do
      pto_adjustment = FactoryGirl.create(:pto_adjustment, creator: user, hours: 10, assigned_pto_policy: user.assigned_pto_policies.first, operation: 1, effective_date: @date + 2.days)
      res = get :index, params: { user_id: user.id }, as: :json
      res = JSON.parse res.body
      expect(res.size).to eq(0)
    end
  end
end
