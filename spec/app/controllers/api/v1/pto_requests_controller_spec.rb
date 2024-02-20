require 'rails_helper'

RSpec.describe Api::V1::PtoRequestsController, type: :controller do

  let(:company) { create(:company, enabled_time_off: true, subdomain: 'pto-company') }
  let(:user) { create(:user, company: company, start_date: Date.today - 1.year ) }
  let(:new_user) { create(:user, state: :active, current_stage: :registered, start_date: Date.today - 1.year, company: company)}
  let(:new_user_offboarded) { create(:user, state: :inactive, current_stage: :departed, start_date: Date.today - 1.year, company: company)}
  let(:admin_user) {create(:peter, company:company, manager: user, start_date: Date.today - 1.year)}
  let(:employee) {create(:nick, :manager_with_role, company:company, start_date: Date.today - 1.year)}

  before do
    allow(controller).to receive(:current_company).and_return(company)
    @date = company.time.to_date
    Sidekiq::Testing.inline! do
      @pto_policy = FactoryGirl.create(:default_pto_policy, company: company)
    end
    User.current = employee
  end

  describe 'authorization' do
    let(:company2) { create(:company, enabled_time_off: true) }
    let!(:pto_request) {create(:default_pto_request, pto_policy: @pto_policy, user_id: employee.id)}
    let(:employee_2) {create(:nick, email: "fast@fast.com", personal_email: "slow@slow.com", company:company)}
    let(:user2) { create(:user, company: company2) }

    it 'should allow user of same company to manage pto' do
      ability = Ability.new(employee)
      assert ability.can?(:manage, pto_request)
    end

    it 'should not allow user of other company to manage pto' do
      ability = Ability.new(user2)
      assert ability.cannot?(:manage, pto_request)
    end

    it 'should allow super_admin of same company to manage pto' do
      ability = Ability.new(user)
      assert ability.can?(:manage, pto_request)
    end

    it 'should allow admin of same company to manage pto' do
      ability = Ability.new(admin_user)
      assert ability.can?(:manage, pto_request)
    end

    it 'should allow manager of user to manage pto' do
      ability = Ability.new(employee.manager)
      assert ability.can?(:manage, pto_request)
    end

    it 'should not allow other employee to manage pto' do
      ability = Ability.new(employee_2)
      assert ability.cannot?(:manage, pto_request)
    end
  end

  describe '#create' do

    context 'Super admin create request' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end
      it 'should be able to create own request' do
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(user.pto_requests.size).to eq(1)
      end

      it 'should be able to create others request' do
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: new_user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(new_user.pto_requests.size).to eq(1)
      end

    end

    context 'Admin create request' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end

      it 'should be able to create own request with view_and_edit permission' do
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: admin_user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(admin_user.pto_requests.size).to eq(1)
      end

      it 'should be able to create own request with view_only permission' do
        admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "view_only"
        admin_user.save!
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: admin_user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(admin_user.pto_requests.size).to eq(1)
      end

      it 'should not e able to create own request with no_access permission' do
        admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "no_access"
        admin_user.save!
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: admin_user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(admin_user.pto_requests.size).to eq(0)
      end

      it 'should not be able to create others request with platform visibility no_access' do
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: new_user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(new_user.pto_requests.size).to eq(0)
      end

      it 'should not be able to create others request with platform visibility view_only' do
        admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_only"
        admin_user.save!
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: new_user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(new_user.pto_requests.size).to eq(0)
      end

      it 'should be able to create others request with platform visibility view_and_edit' do
        admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_and_edit"
        admin_user.save!
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: new_user.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(new_user.pto_requests.size).to eq(1)
      end
    end
    context 'Employee create request' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it 'should not be able to create own request with no_access' do
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(employee.pto_requests.size).to eq(0)
      end

      it 'should be able to create own request with platform visibility view_only' do
        employee.user_role.permissions["platform_visibility"]["time_off"] = "view_only"
        employee.save!
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(employee.pto_requests.size).to eq(1)
      end
    end

    context 'Manager create request' do
      before do
        @manager = employee.manager
        @manager.update(start_date: @manager.start_date - 1.year)
        allow(controller).to receive(:current_user).and_return(@manager)
      end

      it 'should be able to create request' do
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: @manager.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(@manager.pto_requests.size).to eq(1)
      end
      it 'should not be able to create request with no_access' do
        @manager.user_role.permissions["own_platform_visibility"]["time_off"] = "no_access"
        @manager.save!
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: @manager.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(@manager.pto_requests.size).to eq(0)
      end
      it 'should be able to create employee request' do
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(employee.pto_requests.size).to eq(1)
      end

      it 'should not be able to create employee request with platform visibility view_only' do
        manager_role = employee.manager.user_role
        manager_role.permissions["platform_visibility"]["time_off"] = 'view_only'
        manager_role.save!
        res = post :create, params: { begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false }, as: :json
        expect(new_user.pto_requests.size).to eq(0)
      end
    end
  end

  describe '#update #cancel #approve_or_deny' do
    context 'Super admin update/cancel/approve_or_deny request' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        User.current = user
        @own_pto = FactoryGirl.create(:default_pto_request, begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: user.id, balance_hours: 8, partial_day_included: false)
        @others_pto = FactoryGirl.create(:default_pto_request, begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false)
      end
      it 'should be able to update own request' do
        res = put :update, params: { id: @own_pto.id, user_id: user.id, end_date: @date + 1.days, pto_policy_id: @own_pto.pto_policy_id, partial_day_included: false}, as: :json
        expect(res.status).to eq(200)
      end

      it 'should be able to cancel own request' do
        res = put :cancel_request, params: { id: @own_pto.id, user_id: user.id, status: 3 }, as: :json
        expect(res.status).to eq(200)
      end

      it 'should be able to approve_or_deny own request' do
        res = put :approve_or_deny, params: { id: @own_pto.id, user_id: user.id, status: 1 }, as: :json
        expect(res.status).to eq(200)
      end

      it 'should be able to update others request' do
        res = put :update, params: { id: @others_pto.id, user_id: employee.id, end_date: @date + 1.days, pto_policy_id: @others_pto.pto_policy_id, partial_day_included: false }, as: :json
        expect(res.status).to eq(200)
      end

      it 'should be able to cancel others request' do
        res = put :cancel_request, params: { id: @others_pto.id, user_id: employee.id, status: 3 }, as: :json
        expect(res.status).to eq(200)
      end

      it 'should be able to approve_or_deny others request' do
        res = put :approve_or_deny, params: { id: @others_pto.id, user_id: employee.id, status: 1 }, as: :json
        expect(res.status).to eq(200)
      end
    end

    context 'Admin update/cancel/approve_or_deny request' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
        User.current = admin_user
        @own_pto = FactoryGirl.create(:default_pto_request, begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: admin_user.id, balance_hours: 8, partial_day_included: false)
        @others_pto = FactoryGirl.create(:default_pto_request, begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false)
      end
      context 'view_and_edit on self' do
        it 'should be able to update own request' do
          res = put :update, params: { id: @own_pto.id, user_id: admin_user.id, end_date: @date + 1.days, pto_policy_id: @own_pto.pto_policy_id, partial_day_included: false  }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel own request' do
          res = put :cancel_request, params: { id: @own_pto.id, user_id: admin_user.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should not be able to approve_or_deny own request' do
          res = put :approve_or_deny, params: { id: @own_pto.id, user_id: admin_user.id, status: 1 }, as: :json
          expect(res.status).to eq(422)
        end
      end

      context 'view_only on self' do
        before do
          admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "view_only"
          admin_user.save!
        end

        it 'should be able to update own request' do
          res = put :update, params: { id: @own_pto.id, user_id: admin_user.id, end_date: @date + 1.days, pto_policy_id: @own_pto.pto_policy_id, partial_day_included: false  }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should not be able to cancel own request' do
          res = put :cancel_request, params: { id: @own_pto.id, user_id: admin_user.id, status: 3 }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should not be able to approve_or_deny own request' do
          res = put :approve_or_deny, params: { id: @own_pto.id, user_id: admin_user.id, status: 1 }, as: :json
          expect(res.status).to eq(422)
        end
      end

      context 'no_access on self' do
        before do
          admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "no_access"
          admin_user.save!
        end

        it 'should not be able to update own request' do
          res = put :update, params: { id: @own_pto.id, user_id: admin_user.id, end_date: @date + 1.days }, as: :json
          expect(res.status).to eq(204)
        end

        it 'should not be able to cancel own request' do
          res = put :cancel_request, params: { id: @own_pto.id, user_id: admin_user.id, status: 3 }, as: :json
          expect(res.status).to eq(204)
        end

        it 'should not be able to approve_or_deny own request' do
          res = put :approve_or_deny, params: { id: @own_pto.id, user_id: admin_user.id, status: 1 }, as: :json
          expect(res.status).to eq(204)
        end
      end

      context 'no_access on others' do
        it 'should not be able to update others request' do
          res = put :update, params: { id: @others_pto.id, user_id: employee.id, end_date: @date + 1.days }, as: :json
          expect(res.status).to eq(204)
        end

        it 'should not be able to cancel others request' do
          res = put :cancel_request, params: { id: @others_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(204)
        end

        it 'should not be able to approve_or_deny others request' do
          res = put :approve_or_deny, params: { id: @others_pto.id, user_id: employee.id, status: 1 }, as: :json
          expect(res.status).to eq(204)
        end
      end

      context 'view_only on others' do
        before do
          admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_only"
          admin_user.save!
        end
        it 'should not be able to update others request' do
          res = put :update, params: { id: @others_pto.id, user_id: employee.id, end_date: @date + 1.days }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should not be able to cancel others request' do
          res = put :cancel_request, params: { id: @others_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(204)
        end

        it 'should be able to approve_or_deny others request' do
          res = put :approve_or_deny, params: { id: @others_pto.id, user_id: employee.id, status: 1 }, as: :json
          expect(res.status).to eq(200)
        end
      end

      context 'view_and_edit on others' do
        before do
          user_role = admin_user.user_role
          user_role.permissions["platform_visibility"]["time_off"] = "view_and_edit"
          user_role.save!
        end
        it 'should be able to update others request' do
          res = put :update, params: { id: @others_pto.id, user_id: employee.id, end_date: @date + 1.days, pto_policy_id: @others_pto.pto_policy_id, partial_day_included: false  }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel others request' do
          res = put :cancel_request, params: { id: @others_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to approve_or_deny others request' do
          res = put :approve_or_deny, params: { id: @others_pto.id, user_id: employee.id, status: 1 }, as: :json
          expect(res.status).to eq(200)
        end
      end

    end

    context 'employee update/cancel/approve_or_deny' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
        User.current = employee
        @own_pto = FactoryGirl.create(:default_pto_request, begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false)
        @own_past_pto = FactoryGirl.create(:default_pto_request, begin_date: @date - 10.days, end_date: @date -10.days , pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false)
        @own_future_pto = FactoryGirl.create(:default_pto_request, begin_date: @date + 10.days, end_date: @date + 10.days , pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false)
      end

      context 'view_only on self' do
        before do
          employee.user_role.permissions["platform_visibility"]["time_off"] = "view_only"
          employee.save!
        end
        it 'should be able to update future request with view_only' do
          res = put :update, params: { id: @own_future_pto.id,  pto_policy_id: @own_future_pto.pto_policy_id, partial_day_included: false, user_id: employee.id, end_date: @date + 11.day }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel future request with view_only' do
          res = put :cancel_request, params: { id: @own_future_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should not be able to update past request with view_only' do
          res = put :update, params: { id: @own_past_pto.id, user_id: employee.id, end_date: @date + 9.day }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should not be able to approve_or_deny request with view_only' do
          res = put :approve_or_deny, params: { id: @own_pto.id, user_id: employee.id, status: 2 }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should not be able to cancel past request with view_only' do
          res = put :cancel_request, params: { id: @own_past_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should be able to update todays pending request with view_only' do
          res = put :update, params: { id: @own_pto.id, user_id: employee.id, end_date: @date + 9.day, pto_policy_id: @own_pto.pto_policy_id, partial_day_included: false}, as: :json
          expect(res.status).to eq(200)
        end

        it 'should not be able to update todays approved request with view_only' do
          @own_pto.update_column(:status, 1)
          res = put :update, params: { id: @own_pto.id, user_id: employee.id, end_date: @date + 9.day }, as: :json
          expect(res.status).to eq(422)
        end
      end

      context 'view_and_edit on self' do
        before do
          user_role = employee.user_role
          user_role.permissions["platform_visibility"]["time_off"] = "view_and_edit"
          user_role.save!
        end
        it 'should be able to update own request with view_and_edit' do
          res = put :update, params: { id: @own_pto.id, user_id: employee.id, end_date: @date + 1.day, pto_policy_id: @own_pto.pto_policy_id, partial_day_included: false  }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel own request with view_and_edit' do
          res = put :cancel_request, params: { id: @own_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should not be able to approve_or_deny own request with view_and_edit' do
          res = put :approve_or_deny, params: { id: @own_pto.id, user_id: employee.id, status: 2 }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should be able to update past request with view_and_edit' do
          res = put :update, params: { id: @own_past_pto.id, user_id: employee.id, end_date: @own_past_pto.end_date + 1.days, pto_policy_id: @own_past_pto.pto_policy_id, partial_day_included: false}, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel past request with view_and_edit' do
          res = put :cancel_request, params: { id: @own_past_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end
      end

    end

    context 'manager update/cancel request' do
      before do
        @manager = employee.manager
        @manager.update(start_date: @manager.start_date - 1.year)
        allow(controller).to receive(:current_user).and_return(@manager)
        User.current = @manager
        @own_pto = FactoryGirl.create(:default_pto_request, begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: @manager.id, balance_hours: 8, partial_day_included: false)
        @own_past_pto = FactoryGirl.create(:default_pto_request, begin_date: @date - 10.days, end_date: @date -10.days , pto_policy_id: @pto_policy.id, user_id: @manager.id, balance_hours: 8, partial_day_included: false)
        @own_future_pto = FactoryGirl.create(:default_pto_request, begin_date: @date + 10.days, end_date: @date + 10.days , pto_policy_id: @pto_policy.id, user_id: @manager.id, balance_hours: 8, partial_day_included: false)
        @others_pto = FactoryGirl.create(:default_pto_request, begin_date: @date, end_date: @date, pto_policy_id: @pto_policy.id, user_id: employee.id, balance_hours: 8, partial_day_included: false)
      end

      context 'view_and_edit on self' do
        it 'should be able to update own request with view_and_edit' do
          res = put :update, params: { id: @own_pto.id, user_id: @manager.id, end_date: @date + 1.day, pto_policy_id: @own_pto.pto_policy_id, partial_day_included: false  }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel own request with view_and_edit' do
          res = put :cancel_request, params: { id: @own_pto.id, user_id: @manager.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to approve_or_deny own request with view_and_edit' do
          res = put :approve_or_deny, params: { id: @own_pto.id, user_id: @manager.id, status: 2 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to update past request with view_and_edit' do
          res = put :update, params: { id: @own_past_pto.id, user_id: @manager.id, end_date: @own_past_pto.end_date + 1.days, pto_policy_id: @own_past_pto.pto_policy_id, partial_day_included: false }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel past request with view_and_edit' do
          res = put :cancel_request, params: { id: @own_past_pto.id, user_id: @manager.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end
      end
      context 'view_only on self' do
        before do
          user_role = @manager.user_role
          user_role.permissions["own_platform_visibility"]["time_off"] = "view_only"
          user_role.save!
        end
        it 'should be able to update future request with view_only' do
          res = put :update, params: { id: @own_future_pto.id, pto_policy_id: @own_future_pto.pto_policy_id, partial_day_included: false, user_id: @manager.id, end_date: @date + 11.day }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel future request with view_only' do
          res = put :cancel_request, params: { id: @own_future_pto.id, user_id: @manager.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should not be able to update past request with view_only' do
          res = put :update, params: { id: @own_past_pto.id, user_id: @manager.id, end_date: @date + 9.day }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should not be able to approve_or_deny request with view_only' do
          res = put :approve_or_deny, params: { id: @own_pto.id, user_id: @manager.id, status: 2 }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should not be able to cancel past request with view_only' do
          res = put :cancel_request, params: { id: @own_past_pto.id, user_id: @manager.id, status: 3 }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should be able to update todays pending request with view_only' do
          res = put :update, params: { id: @own_pto.id, user_id: @manager.id, end_date: @date + 9.day, pto_policy_id: @own_pto.pto_policy_id, partial_day_included: false }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should not be able to update todays approved request with view_only' do
          @own_pto.update_column(:status, 1)
          res = put :update, params: { id: @own_pto.id, user_id: @manager.id, end_date: @date + 9.day }, as: :json
          expect(res.status).to eq(422)
        end
      end

      context 'view_and_edit on others' do
        it 'should be able to update others request with view_and_edit' do
          res = put :update, params: { id: @others_pto.id, user_id: employee.id, end_date: @date + 1.days, pto_policy_id: @others_pto.pto_policy_id, partial_day_included: false  }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to cancel others request with view_and_edit' do
          res = put :cancel_request, params: { id: @others_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(200)
        end

        it 'should be able to approve_or_deny others request with view_and_edit' do
          res = put :approve_or_deny, params: { id: @others_pto.id, user_id: employee.id, status: 2 }, as: :json
          expect(res.status).to eq(200)
        end
      end

      context 'view_only on others' do
        before do
          user_role = @manager.user_role
          user_role.permissions["platform_visibility"]["time_off"] = "view_only"
          user_role.save!
        end

        it 'should not be able to update others request with view_only' do
          res = put :update, params: { id: @others_pto.id, user_id: employee.id, end_date: @date + 1.days }, as: :json
          expect(res.status).to eq(422)
        end

        it 'should not be able to cancel other request with view_only' do
          res = put :cancel_request, params: { id: @others_pto.id, user_id: employee.id, status: 3 }, as: :json
          expect(res.status).to eq(204)
        end

        it 'should be able to approve_or_deny other request with view_only' do
          res = put :approve_or_deny, params: { id: @others_pto.id, user_id: employee.id, status: 2 }, as: :json
          expect(res.status).to eq(200)
        end
      end
    end
  end



  describe "out of office" do
    let(:policy) {create(:default_pto_policy, company: company)}
    before do
      allow(controller).to receive(:current_user).and_return(user)
    end

    it "should not fetch user having a day before yesterday as their last holiday" do
		  pto_request = FactoryGirl.build(:pto_request, user: user, pto_policy: policy, partial_day_included: false, status: 1, begin_date: @date - 10.days, end_date: @date - 3.days, balance_hours: 24)
      pto_request.save(:validate => false)
      response = get :get_users_out_of_office, params: { status: 1, out_of_office: true }, as: :json
     	result = JSON.parse response.body
     	expect(result["pto_requests"].count).to eq(0)
    end

    it "should fetch user having a future date within 14 days as their last holiday" do
	    pto_request = FactoryGirl.build(:pto_request, user: user, pto_policy: policy, partial_day_included: false, status: 1, begin_date: @date - 10.days, end_date: @date + 3.days, balance_hours: 24)
      pto_request.save(:validate => false)
      response = get :get_users_out_of_office, params: { status: 1, out_of_office: true }, as: :json
     	result = JSON.parse response.body
     	expect(result["pto_requests"][0]["id"]).to eq(pto_request.id)
    end

    it "should not fetch user having a future date exceeding 14 days as their last holiday" do
	    pto_request = FactoryGirl.build(:pto_request, user: user, pto_policy: policy, partial_day_included: false, status: 1, begin_date: @date - 10.days, end_date: @date + 15.days, balance_hours: 24)
      pto_request.save(:validate => false)
      response = get :get_users_out_of_office, params: { status: 1, out_of_office: true }, as: :json
     	result = JSON.parse response.body
     	expect(result["pto_requests"].count).to eq(0)
    end

    it "should not fetch user having a future date as their first holiday" do
		  pto_request = FactoryGirl.build(:pto_request, user: user, pto_policy: policy, partial_day_included: false, status: 1, begin_date: @date + 2.days, end_date: @date + 4.days, balance_hours: 24)
      pto_request.save(:validate => false)
      response = get :get_users_out_of_office, params: { status: 1, out_of_office: true }, as: :json
     	result = JSON.parse response.body
     	expect(result["pto_requests"].count).to eq(0)
    end

    it "should fetch user having today as partial day as their holiday" do
		  pto_request = FactoryGirl.build(:pto_request, user: user, pto_policy: policy, partial_day_included: true, status: 1, begin_date: @date, end_date: @date, balance_hours: 24)
      pto_request.save(:validate => false)
      response = get :get_users_out_of_office, params: { status: 1, out_of_office: true }, as: :json
     	result = JSON.parse response.body
     	expect(result["pto_requests"][0]["id"]).to eq(pto_request.id)
    end

    it "should fetch users for updates page" do
      pto_request = FactoryGirl.build(:pto_request, user: new_user, pto_policy: policy, partial_day_included: true, status: 1, begin_date: @date - 2.days, end_date: @date + 3.days, balance_hours: 24)
      pto_request.save(:validate => false)
      pto_request2 = FactoryGirl.build(:pto_request, user: new_user_offboarded, pto_policy: policy, partial_day_included: false, status: 1, begin_date: @date - 2.days, end_date: @date + 3.days, balance_hours: 24)
      pto_request2.save(:validate => false)
      response = get :get_users_out_of_office, params: { active_employees: true, status: 1, out_of_office: true }, as: :json
      result = JSON.parse response.body
      expect(result["meta"]["count"]).to eq(1)
      expect(result["pto_requests"][0]["user_id"]).to eq(new_user.id)
    end
  end

  describe '#show' do
  	before(:all) do
  	  @response_keys = ["id", "begin_date", "end_date", "policy_name",
				"status", "pto_policy_id", "partial_day_included", "additional_notes",
				"user_full_name", "user_image", "approval_denial_date", "activities", "user_id",
				"user_initials", "balance_hours", "policy_enabled", "created_timestamp",
				"policy_tracking_unit", "is_past", "working_hours", "policy_available_hours",
				"policy_hours_used", "policy_scheduled_hours", "approvers", "is_manager_approval_remaining", "user_display_name", "return_date", "carryover_balance", "remaining_balance", "attachments"]
  	end
  	context 'unauthenticated user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return 401 response' do
  			pto_request = FactoryGirl.create(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)
        response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
        expect(response.status).to eq(401)
  		end
  	end
    context 'Super admin can view pto request' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end
      it "should be able to view own pto request" do
        pto_request = FactoryGirl.create(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)
        response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
        expect(response.response_code).to eq(200)
        expect(JSON.parse(response.body).keys).to eq(@response_keys)
      end

      it "should be able to view other's pto request" do
        pto_request = FactoryGirl.create(:pto_request, user: new_user, pto_policy: new_user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)
        response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
        expect(response.response_code).to eq(200)
        expect(JSON.parse(response.body).keys).to eq(@response_keys)
      end
    end

    context 'Admin can view pto request' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
        @pto_request = FactoryGirl.create(:pto_request, user: admin_user, pto_policy: admin_user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)
      end
      it "should be able to view own pto request with view_and_edit permissions" do
        response = get :show, params: { user_id: @pto_request.user.id, id: @pto_request.id }
        expect(response.response_code).to eq(200)
        expect(JSON.parse(response.body).keys).to eq(@response_keys)
      end

      it "should be able to view own pto request with view_only permissions" do
        admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "view_only"
        admin_user.save!
        response = get :show, params: { user_id: @pto_request.user.id, id: @pto_request.id }
        expect(response.response_code).to eq(200)
        expect(JSON.parse(response.body).keys).to eq(@response_keys)
      end

      it "should not be able to view own pto request with no_access permissions" do
        admin_user.user_role.permissions["own_platform_visibility"]["time_off"] = "no_access"
        admin_user.save!
        response = get :show, params: { user_id: @pto_request.user.id, id: @pto_request.id }
        expect(response.response_code).to eq(204)
      end

      context 'on others profile' do
        let(:pto_request) {FactoryGirl.create(:pto_request, user: new_user, pto_policy: new_user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)}
        it 'should not be able to view others request with platform visibility no_access' do
          response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
          expect(response.response_code).to eq(204)
        end

        it 'should be able to view others request with platform visibility view_only' do
          admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_only"
          admin_user.save!
          response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
          expect(response.response_code).to eq(200)
          expect(JSON.parse(response.body).keys).to eq(@response_keys)
        end

        it 'should be able to view others request with platform visibility view_and_edit' do
          admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_and_edit"
          admin_user.save!
          response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
          expect(response.response_code).to eq(200)
          expect(JSON.parse(response.body).keys).to eq(@response_keys)
        end
      end
    end

    context 'Employee view request' do
      let(:pto_request) {FactoryGirl.create(:pto_request, user: employee, pto_policy: employee.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)        }
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be able to view own request with no_access' do
        response = get :show, params: { id: pto_request.id, user_id: pto_request.user.id }
        expect(response.response_code).to eq(204)
      end

      it 'should be able to view own request with platform visibility view_only' do
        employee.user_role.permissions["platform_visibility"]["time_off"] = "view_only"
        employee.save!
        response = get :show, params: { id: pto_request.id, user_id: pto_request.user.id }
        expect(response.response_code).to eq(200)
        expect(JSON.parse(response.body).keys).to eq(@response_keys)
      end

      it 'should be able to view own request with platform visibility view_and_edit' do
        employee.user_role.permissions["platform_visibility"]["time_off"] = "view_and_edit"
        employee.save!
        response = get :show, params: { id: pto_request.id, user_id: pto_request.user.id }
        expect(response.response_code).to eq(200)
        expect(JSON.parse(response.body).keys).to eq(@response_keys)
      end
    end

    context 'Manager view request' do
      before do
        @manager = employee.manager
        @manager.update(start_date: @manager.start_date - 1.year)
        allow(controller).to receive(:current_user).and_return(@manager)
      end
      context 'own tab' do
        let(:pto_request) {FactoryGirl.create(:pto_request, user: @manager, pto_policy: @manager.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)}
        it 'should be able to view request' do
          response = get :show, params: { id: pto_request.id, user_id: pto_request.user.id }
          expect(response.response_code).to eq(200)
          expect(JSON.parse(response.body).keys).to eq(@response_keys)
        end

        it 'should not be able to view request with no_access' do
          @manager.user_role.permissions["own_platform_visibility"]["time_off"] = "no_access"
          @manager.save!
          response = get :show, params: { id: pto_request.id, user_id: pto_request.user.id }
          expect(response.response_code).to eq(204)
        end
      end

      context 'on employees tab' do
        let(:pto_request) {FactoryGirl.create(:pto_request, user: employee, pto_policy: employee.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)}

        it 'should be able to view employee request' do
          response = get :show, params: { id: pto_request.id, user_id: pto_request.user.id }
          expect(response.response_code).to eq(200)
        end

        it 'should be able to view employee request with platform visibility view_only' do
          manager_role = employee.manager.user_role
          manager_role.permissions["platform_visibility"]["time_off"] = "view_only"
          manager_role.save!
          response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
          expect(response.response_code).to eq(200)
          expect(JSON.parse(response.body).keys).to eq(@response_keys)
        end
      end
      context 'on others tab' do
        it "should not be able to view other's pto request" do
          pto_request = FactoryGirl.create(:pto_request, user: new_user, pto_policy: new_user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days, balance_hours: 24)
          response = get :show, params: { user_id: pto_request.user.id, id: pto_request.id }
          expect(response.response_code).to eq(204)
        end
      end
    end
  end

  describe '#hours_used' do

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    context 'limited policy' do
      it "should return hours used for pto_request and available_balance" do
        pto_request = FactoryGirl.build(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days)
        response = get :hours_used, params: { user_id: pto_request.user.id, begin_date: pto_request.begin_date, end_date: pto_request.end_date, partial_day_included: pto_request.partial_day_included, pto_policy_id: pto_request.pto_policy_id }
        expect(response.response_code).to eq(200)
        expect((JSON.parse response.body)["hours_used"]).to eq(pto_request.get_balance_used)
        expect((JSON.parse response.body)["available_balance"]).to_not eq(nil)
      end
    end

    context 'unlimited policy' do
      before {user.pto_policies.first.update(unlimited_policy: true)}
      it "should return hours used for pto_request and available_balance as nil" do
        pto_request = FactoryGirl.build(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 1, begin_date: @date - 3.days, end_date: @date + 4.days)
        response = get :hours_used, params: { user_id: pto_request.user.id, begin_date: pto_request.begin_date, end_date: pto_request.end_date, partial_day_included: pto_request.partial_day_included, pto_policy_id: pto_request.pto_policy_id }
        expect(response.response_code).to eq(200)
        expect((JSON.parse response.body)["hours_used"]).to eq(pto_request.get_balance_used)
        expect((JSON.parse response.body)["available_balance"]).to eq(nil)
      end
    end
  end

  describe 'Requests on time of tab' do

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    context 'Historical' do
      it "should be able to view historical pto request" do
        pto_request = FactoryGirl.create(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 1, begin_date: company.time.to_date - 3.days, end_date: Date.today, balance_hours: 24)
        response = get :historical_requests, params: { user_id: pto_request.user.id }, as: :json
        result = JSON.parse response.body
        expect(result.count).to eq(1)
      end

      it "should not be able to view previous year's historical requests on first page" do
        pto_request = FactoryGirl.create(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 1, begin_date: company.time.to_date - 364.days, end_date: company.time.to_date - 364.days, balance_hours: 24)
        response = get :historical_requests, params: { user_id: pto_request.user.id }, as: :json
        result = JSON.parse response.body
        expect(result.count).to eq(0)
      end
    end

    context 'Upcoming requests' do
      it "should be able to view Upcoming pto request" do
        pto_request = FactoryGirl.create(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 1, begin_date: company.time.to_date + 365.days, end_date: company.time.to_date + 368.days, balance_hours: 24)
        response = get :upcoming_requests, params: { user_id: pto_request.user.id }, as: :json
        result = JSON.parse response.body
        expect(result.count).to eq(1)
      end
    end
  end

  describe '#destroy' do

    context 'Super admin can delete pto request' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        pto_policy = user.pto_policies.first
        @pto_request = FactoryGirl.create(:pto_request, user: user, pto_policy: pto_policy, partial_day_included: false, status: 1, begin_date: company.time.to_date - 3.days, end_date: company.time.to_date - 3.days, balance_hours: 24)
        pto_policy.update_column(:is_enabled, false)
        @pto_request.assigned_pto_policy.destroy
        @response = delete :destroy, params: { user_id: @pto_request.user.id, id: @pto_request.id }, as: :json
      end

      it "should be able to destroy pto request with disabled policy" do
        expect(response.response_code).to eq(204)
      end

      it "should not get request" do
        expect(PtoRequest.find_by(id: @pto_request.id)).to eq(nil)
      end
    end
  end

  describe 'approve_or_deny' do
    before do
      employee.pto_policies.first.approval_chains << FactoryGirl.create(:approval_chain, approval_type: ApprovalChain.approval_types[:permission], approval_ids: ["all"])
      @pto_request = FactoryGirl.create(:pto_request, user: employee, pto_policy: employee.pto_policies.first, partial_day_included: false, status: 0, begin_date: company.time.to_date - 3.days, end_date: company.time.to_date - 3.days, balance_hours: 24)
      admin_user.user_role.permissions["platform_visibility"]["time_off"] = "view_and_edit"
      admin_user.save!
    end

    it 'super_admin should be able to approve the request' do
      allow(controller).to receive(:current_user).and_return(user)
      res = put :approve_or_deny, params: { id: @pto_request.id, user_id: employee.id, status: 1 }, as: :json
      expect(res.status).to eq(200)
    end

    it 'admin should be able to approve the request' do
      allow(controller).to receive(:current_user).and_return(admin_user)
      res = put :approve_or_deny, params: { id: @pto_request.id, user_id: employee.id, status: 1 }, as: :json
      expect(res.status).to eq(200)
    end


    it 'persons from approvl chain should be able to approve the request' do
      allow(controller).to receive(:current_user).and_return(employee.manager)
      res = put :approve_or_deny, params: { id: @pto_request.id, user_id: employee.id, status: 1 }, as: :json
      expect(res.status).to eq(200)

      allow(controller).to receive(:current_user).and_return(admin_user)
      res = put :approve_or_deny, params: { id: @pto_request.id, user_id: employee.id, status: 1 }, as: :json
      expect(res.status).to eq(200)
    end

    it 'other person than the approvl chain should not be able to approve the request' do
      allow(controller).to receive(:current_user).and_return(employee)
      res = put :approve_or_deny, params: { id: @pto_request.id, user_id: employee.id, status: 1 }, as: :json
      expect(res.status).to eq(204)
    end
  end
end
