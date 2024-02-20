require 'rails_helper'
require 'sidekiq/testing'
RSpec.describe :UsersControllerPart3, type: :controller do
  def self.described_class
    Api::V1::Admin::UsersController
  end

  let(:company) { create(:gsuite_integration, is_using_custom_table: false , send_notification_before_start: true) }
  let(:other_company) { create(:company, subdomain: 'boo', is_using_custom_table: true) }
  let(:other_user) { create(:user, state: :active, current_stage: :registered, company: other_company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: user1.id) }
  let(:location) { create(:location, name: 'Test Location', company: company) }
  let(:team) { create(:team, name: 'Test Team', company: company) }
  let!(:employee) { create(:user, state: :active, current_stage: :registered, company: company, manager: user, location: location, team: team, role: User.roles[:employee]) }
  let(:tim) { create(:tim, company: company) }
  let(:nick) { create(:nick, :manager_with_role, company: company) }
  let(:admin) { create(:peter, company: company) }
  let(:super_admin) { create(:user, company: company) }
  let(:manager) { create(:user, company: company, role: User.roles[:employee]) }
  let(:admin_no_access) {create(:with_no_access_for_all, role_type: 2, company: company)}
  let(:task) { create(:task) }
  let!(:webhook) {create(:webhook, event: 'onboarding', configurable: { stages: ['all'] }, company: company)}

  before do
    allow(controller).to receive(:current_user).and_return(super_admin)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe '#update_termination_date' do
    subject(:request) { post :update_termination_date, params: { id: employee.id, termination_date: Time.now.in_time_zone(company.time_zone).to_date }, format: :json }
    context "should not update_termination_date" do
      it "should return unauthorised status and doesnot invite_user for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot update_termination_date for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot update_termination_date if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should update_termination_date" do
      it 'should return ok status and update own update_termination_date if current user is employee ' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect{request}.to change{employee.reload.termination_date}.from(employee.termination_date).to(Time.now.in_time_zone(company.time_zone).to_date)
      end

      it 'should update_termination_date users if current current_user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        expect{request}.to change{employee.reload.termination_date}.from(employee.termination_date).to(Time.now.in_time_zone(company.time_zone).to_date)
      end

      it 'should update_termination_date if current user is super admin' do
        expect{request}.to change{employee.reload.termination_date}.from(employee.termination_date).to(Time.now.in_time_zone(company.time_zone).to_date)
      end
    end
  end

  describe '#activity_owners' do
    subject(:request) { get :activity_owners, params: { type: 'document' }, format: :json }
    before do
      task_user_connection = create(:task_user_connection, user: employee, task: task, state: 'in_progress')
    end
    context "should not get activity_owners" do
      it "should return unauthorised status and doesnot get activity_owners for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot get activity_owners for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot get activity_owners if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot get activity_owners if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should get activity_owners" do
      it 'should get activity_owners to users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :activity_owners, params: { id: employee.id, type: 'document' }, format: :json

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body).keys.count).to eq(1)
        expect(JSON.parse(response.body).keys).to eq(["paperwork_requests"])
      end

      it 'should get activity_owners to users if current user is super admin' do
        get :activity_owners, params: { id: employee.id, type: 'task' }, format: :json

        result = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        expect(result.keys.count).to eq(1)
        expect(result.keys).to eq(["users"])
        expect(result["users"][0].keys.count).to eq(20)
        expect(result["users"][0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                               "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                               "about_you", "provider", "display_name_format", "title", "location_name",
                                               "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                               "picture", "email", "activity_count", "location"])
      end
    end
  end

  describe '#set_manager' do
    subject(:request) { post :set_manager, params: { id: employee.id, manager: nick.id }, format: :json }

    context "should not set_manager" do
      it "should return unauthorised status and doesnot set_manager for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot set_manager for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot set_manager if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should set_manager" do
      it 'should set own manager if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        post :set_manager, params: { id: employee.id, manager: nick.id }, format: :json

        expect(response).to have_http_status(201)
        expect(employee.reload.manager.id).to eq(nick.id)

      end

      it 'should set_manager if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        post :set_manager, params: { id: employee.id, manager: nick.id }, format: :json

        expect(response).to have_http_status(201)
        expect(employee.reload.manager.id).to eq(nick.id)
      end

      it 'should set_manager if current user is super admin' do
        post :set_manager, params: { id: employee.id, manager: nick.id }, format: :json

        expect(response).to have_http_status(201)
        expect(employee.reload.manager.id).to eq(nick.id)
      end

      it 'should set_manager and create snapshot if current user is super admin and company is using custom_tables' do
        allow(controller).to receive(:current_user).and_return(other_user)
        allow(controller).to receive(:current_company).and_return(other_company)
        post :set_manager, params: { id: other_user.id, manager: nick.id }, format: :json

        expect(response).to have_http_status(201)
        expect(other_user.reload.manager.id).to eq(nick.id)
        expect(other_user.custom_table_user_snapshots.count).to eq(1)
      end
    end
  end

  describe '#update_pending_hire_user' do
    subject(:request) { post :update_pending_hire_user, params: { id: employee.id }, format: :json }
    before do
      pending_hire = create(:incomplete_pending_hire, user: employee, company: company)
    end
    context "should not update_pending_hire_user" do
      it "should return unauthorised status and doesnot get activity_owners for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot update_pending_hire_user for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot update_pending_hire_user if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end

       it 'should return no content status and doesnot update own pending_hire_user if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot update_pending_hire_user if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        expect(request).to have_http_status(204)
      end
    end

    context "should update_pending_hire_user" do
      it 'should update_pending_hire_user if current user is super admin' do
        post :update_pending_hire_user, params: { id: employee.id }, format: :json

        expect(response).to have_http_status(204)
        expect(employee.reload.pending_hire.deleted_at).not_to eq(nil)
        expect(employee.first_name).to eq(employee.pending_hire.first_name)
        expect(employee.last_name).to eq(employee.pending_hire.last_name)
      end

      it 'should update_pending_hire_user if current user is super admin and compnay is using custom table' do
        company.update!(is_using_custom_table: true)
        post :update_pending_hire_user, params: { id: employee.id }, format: :json

        expect(response).to have_http_status(204)
        expect(employee.reload.pending_hire.deleted_at).not_to eq(nil)
        expect(employee.first_name).to eq(employee.pending_hire.first_name)
        expect(employee.last_name).to eq(employee.pending_hire.last_name)
      end
    end
  end

  describe '#fetch_role_users' do
    subject(:request) { get :fetch_role_users, format: :json }

    context "should not fetch_role_users" do
      it "should return unauthorised status and doesnot send_documents_email for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot fetch_role_users for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot fetch_role_users if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot fetch_role_users if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should fetch_role_users" do
      it 'should send fetch_role_users to users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :fetch_role_users, format: :json

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)[0].keys.count).to eq(18)
        expect(JSON.parse(response.body)[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                                         "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                                         "about_you", "provider", "display_name_format", "title", "location_name",
                                                         "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                                         "picture", "profile_image"])

      end

      it 'should send fetch_role_users to users if current user is super admin' do
        get :fetch_role_users, format: :json

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)[0].keys.count).to eq(18)
        expect(JSON.parse(response.body)[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                                         "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                                         "about_you", "provider", "display_name_format", "title", "location_name",
                                                         "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                                         "picture", "profile_image"])
      end
    end
  end

  describe '#restore_user_snapshots' do
    subject(:request) { post :restore_user_snapshots, params: { id: employee.id }, format: :json }

    context "should not restore_user_snapshots" do
      it "should return unauthorised status and doesnot restore_user_snapshots for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot restore_user_snapshots for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot restore_user_snapshots if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should restore_user_snapshots" do
      it 'should  not restore_user_snapshots to users if current user is admin and company is not using custom table' do
        allow(controller).to receive(:current_user).and_return(admin)

        expect(request).to have_http_status(204)
      end

      it 'should return ok status if current user is employee and company is not using custom table' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end

      it 'should not send email if feature flag is off and send asana task if asana integration if present if current user is super admin' do
        user = create(:user_with_past_snapshot, company: other_company)
        allow(controller).to receive(:current_user).and_return(user)
        allow(controller).to receive(:current_company).and_return(other_company)
        user.custom_table_user_snapshots.take.update(terminated_data: {termination_type: 'voluntary'})
        post :restore_user_snapshots, params: { id: user.id }, format: :json

        expect(response).to have_http_status(204)
        expect(user.reload.termination_type).to eq('voluntary')
      end
    end
  end

  describe '#send_onboarding_emails' do
    subject(:request) { post :send_onboarding_emails, params: { id: employee.id }, format: :json }

    context "should not send_onboarding_emails" do
      it "should return unauthorised status and doesnot send_onboarding_emails for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot send_onboarding_emails for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot send_onboarding_emails if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should send_onboarding_emails" do
      it 'should return ok status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end

      it 'should send email if feature flag is on and send asana task if asana integration is present for current user as super admin' do
        asana = create(:asana_integration, company: company)
        post :send_onboarding_emails, params: { id: employee.id }, format: :json

        expect(response).to have_http_status(204)
        expect(Sidekiq::Queues["schedule_email"].size).not_to eq(0)
      end
    end

    context "onboarding_started_webhook" do
      it "should send_onboarding_started_webhook" do
        expect(Sidekiq::Queues["webhook_activities"].size).not_to eq(0)
      end
    end
  end

  describe '#scheduled_email_count' do
    subject(:request) { post :scheduled_email_count, params: { id: employee.id }, format: :json }

    it 'should return ok status' do
      post :scheduled_email_count, params: { id: employee.id, type:["start date", "anniversary", "date of termination", "last day worked"] }, format: :json
      expect(request).to have_http_status(200)
    end
  end

  describe 'bulk-reassign-manager' do
    it 'should reassign managers to user as per give data array if company is not using custom tables' do
      manager_a = FactoryGirl.create(:user, company: company, email: "managerA@test.com")
      manager_b = FactoryGirl.create(:user, company: company, email: "managerB@test.com")

      user_a = FactoryGirl.create(:user, company: company, email: "userA@test.com")
      user_b = FactoryGirl.create(:user, company: company, email: "userB@test.com")

      user_a.manager_id = manager_a.id
      user_b.manager_id = manager_a.id

      expect(user_a.manager_id).to eq(manager_a.id)
      expect(user_b.manager_id).to eq(manager_a.id)
      Sidekiq::Testing.inline! do
        data_array = []
        data_array.push([user_a.id , manager_b.id])
        data_array.push([user_b.id , manager_b.id])

        result = post :bulk_update_managers, params: { data: data_array }, as: :json

        expect(result.status).to eq(200)

        user_a.reload
        user_b.reload

        expect(user_a.manager_id).to eq(manager_b.id)
        expect(user_b.manager_id).to eq(manager_b.id)
      end
    end
  end

  describe 'assign_individual_policy' do

    before do
      @pto_policy = FactoryGirl.create(:default_pto_policy)
      @date = @pto_policy.company.time.to_date
    end

    context 'on past date' do

      it 'should assign that policy immediately' do
        response = post :assign_individual_policy, params: { id: user.id, selected_policy: @pto_policy.id, effective_date: (@date - 1.days).to_s, starting_balance: 10 }, format: :json
        expect(user.assigned_pto_policies.size).to eq(1)
        expect(user.assigned_pto_policies.first.pto_policy_id).to eq(@pto_policy.id)
        expect(JSON.parse(response.body)["id"]).to eq(@pto_policy.id)
      end

    end
    context 'on current date' do

      it 'should assign that policy immediately' do
        response = post :assign_individual_policy, params: { id: user.id, selected_policy: @pto_policy.id, effective_date: @date.to_s, starting_balance: 10 }, format: :json
        expect(user.assigned_pto_policies.size).to eq(1)
        expect(user.assigned_pto_policies.first.pto_policy_id).to eq(@pto_policy.id)
        expect(JSON.parse(response.body)["id"]).to eq(@pto_policy.id)
      end

    end

    context 'on future date' do

      it 'should create unassigned_pto_policy' do
        response = post :assign_individual_policy, params: { id: user.id, selected_policy: @pto_policy.id, effective_date: (@date + 1.days).to_s, starting_balance: 10 }, format: :json
        expect(JSON.parse(response.body)["assign_later"]).to eq(true)
        expect(user.unassigned_pto_policies.size).to eq(1)
        expect(user.unassigned_pto_policies.first.pto_policy_id).to eq(@pto_policy.id)
        expect(user.unassigned_pto_policies.first.user_id).to eq(user.id)
      end

    end
  end

  describe 'unassign_policy' do

    before do
      @user = create(:user_manual_assigned_policy_factory, company: company)
    end

    context 'without pto adjustments' do

      it 'removes that policy' do
        response = post :unassign_policy, params: { id: @user.id, selected_policy_id: @user.assigned_pto_policies.first.pto_policy_id }, format: :json
        expect(@user.reload.assigned_pto_policies.size).to eq(0)
      end

    end

    context 'with pto adjustments' do

      it 'removes policy with pto adjustments' do
        create(:pto_adjustment, assigned_pto_policy_id: @user.assigned_pto_policies.first.id, creator: user)
        response = post :unassign_policy, params: { id: @user.id, selected_policy_id: @user.assigned_pto_policies.first.pto_policy_id }, format: :json
        expect(@user.reload.assigned_pto_policies.size).to eq(0)
        expect(PtoAdjustment.all.size).to eq(0)
      end

    end

  end

  describe 'assign_individual_policy being accessed' do

    context 'by employee' do

      before do
        @nick = create(:nick, company: company)
        @pto_policy = create(:default_pto_policy, company: company)
        allow(controller).to receive(:current_user).and_return(@nick)
        @date = @pto_policy.company.time.to_date
      end

      it 'should not allow to assign policy' do
        post :assign_individual_policy, params: { id: @nick.id, selected_policy: @pto_policy.id, effective_date: (@date + 1.days).to_s, starting_balance: 10 }, format: :json
        expect(@nick.reload.assigned_pto_policies.size).to eq(0)
        expect(@nick.reload.unassigned_pto_policies.size).to eq(0)
      end

    end

  end

  describe 'unassign_policy' do

    context 'which was not manually_assigned' do

      before do
        @nick = create(:user_manual_assigned_policy_factory, :not_assigned_manually, company: company)
      end

      it 'should not allow to unassign policy' do
        post :unassign_policy, params: { id: @nick.id, selected_policy_id: @nick.assigned_pto_policies.first.pto_policy_id }, format: :json
        expect(@nick.reload.assigned_pto_policies.size).to eq(1)
      end

    end

    context 'which is for all employees' do
      before do
        @nick = create(:user_manual_assigned_policy_factory, company: company)
        @nick.pto_policies.first.update_column(:for_all_employees, true)
      end

      it 'should not allow to unassign policy' do
        post :unassign_policy, params: { id: @nick.id, selected_policy_id: @nick.assigned_pto_policies.first.pto_policy_id }, format: :json
        expect(@nick.reload.assigned_pto_policies.size).to eq(1)
      end
    end

    context 'being accessed by employee' do

      before do
        @nick = create(:user_manual_assigned_policy_factory, company: company)
        allow(controller).to receive(:current_user).and_return(@nick)
      end

      it 'should not allow to unassign policy' do
        post :unassign_policy, params: { id: @nick.id, selected_policy_id: @nick.assigned_pto_policies.first.pto_policy_id }, format: :json
        expect(@nick.reload.assigned_pto_policies.size).to eq(1)
      end

    end

  end

  describe 'POST #create_onboard_custom_snapshots' do
    let(:company) { create(:company) }

     before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context 'should not create onboard custom snapshots' do
      context 'should not create onboard custom snapshots for unauthenticated user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :create_onboard_custom_snapshots, params: { id: super_admin.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context 'should not create onboard custom snapshots for other company' do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status for other company user' do
          post :create_onboard_custom_snapshots, params: { id: other_user.id, sub_tab: 'dashboard' }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should return no content status if current user is of other company' do
          allow(controller).to receive(:current_user).and_return(other_user)
          post :create_onboard_custom_snapshots, params: { id: other_user.id, sub_tab: 'dashboard' },format: :json
          expect(response.status).to eq(204)
        end
      end

      context 'should not create onboard custom snapshots if super admin has no dashboard access' do
        before do
          disable_dashboard_access(super_admin.user_role)
          post :create_onboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no content status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create onboard custom snapshots if admin has no dashboard access' do
        before do
          disable_dashboard_access(admin.user_role)
          allow(controller).to receive(:current_user).and_return(admin)
          post :create_onboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no content status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create onboard custom snapshots as per manager permission' do
        before do
          employee.update(manager_id: manager.id)
          manager.reload
          allow(controller).to receive(:current_user).and_return(manager)
          post :create_onboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no context status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create onboard custom snapshots as per employee permission' do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          post :create_onboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return forbidden status" do
          expect(response.status).to eq(204)
        end
      end
    end

    context 'should create onboard custom snapshots' do
      context 'should create onboard custom snapshots if sub tab is not present' do
        before do
          post :create_onboard_custom_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create onboard custom snapshots as per super admin permission' do
        before do
          post :create_onboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create onboard custom snapshots as per admin permission' do
        before do
          allow(controller).to receive(:current_user).and_return(admin)
          post :create_onboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create role information custom snapshots' do
        before do
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
          @custom_fields = @custom_table.custom_fields
          post :create_onboard_custom_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          expect(employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user and effective date value is equal to user start date and assign custom field custom snapshot value to user' do
            custom_field = @custom_fields.find_by(name: 'Effective Date')
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(employee.start_date.to_s)

            @custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date'
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
                expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end
          end
        end

        context 'should assign preference fields custom snapshot value to user' do
          it 'should assign manager, title, department, location to user' do
            snapshot_value = CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(employee.manager_id).to eq(snapshot_value.to_i)
            expect(employee.title).to eq(CustomSnapshot.where(preference_field_id: 'jt', custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)
            expect(employee.team_id).to eq(CustomSnapshot.where(preference_field_id: 'dpt', custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value.to_i)
            expect(employee.location_id).to eq(CustomSnapshot.where(preference_field_id: 'loc', custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value.to_i)
          end
        end
      end

      context 'should create employment status custom snapshots' do
        before do
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
          @custom_fields = @custom_table.custom_fields
          @custom_fields.each do |custom_field|
            if custom_field.field_type == 'employment_status'
              employee.custom_field_values << create(:custom_field_value, custom_field: custom_field, custom_field_option_id: custom_field.custom_field_options.find_by(option: 'Full Time').try(:id))
            elsif custom_field.name != 'Effective Date'
              employee.custom_field_values << create(:custom_field_value, custom_field: custom_field)
            end
          end
          post :create_onboard_custom_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          expect(employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user and effective date value is equal to user start date and assign custom field custom snapshot value to user and assign employment status custom snapshot value to user' do
            custom_field = @custom_fields.find_by(name: 'Effective Date')
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(employee.start_date.to_s)

            @custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date' && custom_field.field_type != 'employment_status'
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
                expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end

            custom_field = @custom_fields.find_by(field_type: 13)
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_i)
          end
        end

        context 'should assign preference fields custom snapshot value to user' do
          it 'should assign manager value to user' do
            snapshot_value = CustomSnapshot.where(preference_field_id: 'st', custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(employee.state).to eq(snapshot_value)
          end
        end
      end

      context 'should create compensation custom snapshots' do
        before do
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:compensation])
          @custom_fields = @custom_table.custom_fields
          @custom_fields.each do |custom_field|
            if custom_field.field_type == 'currency'
              employee.custom_field_values << create(:custom_field_value, sub_custom_field: custom_field.sub_custom_fields.first, value_text: 'USD')
              employee.custom_field_values << create(:custom_field_value, sub_custom_field: custom_field.sub_custom_fields.second, value_text: '200')
            elsif custom_field.name != 'Effective Date'
              employee.custom_field_values << create(:custom_field_value, custom_field: custom_field)
            end
          end
          post :create_onboard_custom_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          expect(employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user and effective date value is equal to user start date and assign custom fields custom snapshot value to user' do
            custom_field = @custom_fields.find_by(name: 'Effective Date')
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(employee.start_date.to_s)

            custom_field = @custom_fields.find_by(field_type: 14)
            expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)

            @custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date' && custom_field.field_type != 'currency'
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
                expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end
          end
        end
      end

      context 'should create timeline table custom snapshots' do
        before do
          @employee = create(:user_with_timeline_custom_table, company: company)
          @custom_table = company.custom_tables.find_by(table_type: CustomTable.table_types[:timeline], custom_table_property: CustomTable.custom_table_properties[:general])
          post :create_onboard_custom_snapshots, params: { id: @employee.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          expect(@employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user and effective date value is equal to user start date and assign custom fields custom snapshot value to user' do
            custom_field = @custom_table.custom_fields.find_by(name: 'Effective Date')
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(@employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(@employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(@employee.start_date.to_s)
            @custom_table.custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date'
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
                expect(@employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end
          end

        end
      end

      context 'should create standard table custom snapshots' do
        before do
          @employee = create(:user_with_standard_custom_table, company: company)
          @custom_table = company.custom_tables.find_by(table_type: CustomTable.table_types[:standard])
          post :create_onboard_custom_snapshots, params: { id: @employee.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot and assign custom field custom snapshot value to user" do
          expect(response.status).to eq(200)
          expect(@employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
          @custom_table.custom_fields.each do |custom_field|
              snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
              expect(@employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
          end
        end
      end

      context 'should create or update existing snapshot during onboarding for each table' do
        before do
          @user_with_past_snapshot = create(:user_with_past_snapshot, company: company)
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
          @custom_fields = @custom_table.custom_fields
          @custom_fields.each do |custom_field|
            if custom_field.field_type == 'employment_status'
              @user_with_past_snapshot.custom_field_values << create(:custom_field_value, custom_field: custom_field, custom_field_option_id: custom_field.custom_field_options.find_by(option: 'Full Time').try(:id))
            elsif custom_field.name != 'Effective Date'
              @user_with_past_snapshot.custom_field_values << create(:custom_field_value, custom_field: custom_field)
            end
          end
          post :create_onboard_custom_snapshots, params: { id: @user_with_past_snapshot.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          expect(@user_with_past_snapshot.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
        end

        it 'should update existing snapshot' do
          expect(@user_with_past_snapshot.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).count).to eq(1)
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user and effective date value is equal to user start date and assign custom field custom snapshot value to user and assign employment status custom snapshot value to user' do
            custom_field = @custom_fields.find_by(name: 'Effective Date')
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @user_with_past_snapshot.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(@user_with_past_snapshot.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(@user_with_past_snapshot.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(@user_with_past_snapshot.start_date.to_s)

            @custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date' && custom_field.field_type != 'employment_status'
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @user_with_past_snapshot.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
                expect(@user_with_past_snapshot.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end

            custom_field = @custom_fields.find_by(field_type: 13)
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @user_with_past_snapshot.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(@user_with_past_snapshot.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_i)
          end
        end

        context 'should assign preference fields custom snapshot value to user' do
          it 'should assign manager value to user' do
            snapshot_value = CustomSnapshot.where(preference_field_id: 'st', custom_table_user_snapshot_id: @user_with_past_snapshot.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(@user_with_past_snapshot.state).to eq(snapshot_value)
          end
        end
      end
    end
  end

  describe 'POST #create_offboard_custom_snapshots' do
    let(:company) { create(:company, time_zone: 'Pacific Time (US & Canada)') }

    before do
      @custom_field = company.custom_fields.find_by(name: 'Employment Status')
      @custom_field_option = @custom_field.custom_field_options.find_by(option: 'Full Time')

      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context 'should not create offboard custom snapshots' do
      context 'should not create offboard custom snapshots for unauthenticated user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :create_offboard_custom_snapshots, params: { id: super_admin.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context 'should not create offboard custom snapshots for other company' do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status for other company user' do
          post :create_offboard_custom_snapshots, params: { id: other_user.id, sub_tab: 'dashboard' }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should return no content status if current user is of other company' do
          allow(controller).to receive(:current_user).and_return(other_user)
          post :create_offboard_custom_snapshots, params: { id: other_user.id, sub_tab: 'dashboard' }, format: :json
          expect(response.status).to eq(204)
        end
      end

      context 'should create offboard custom snapshots if super admin has no dashboard access' do
        before do
          disable_dashboard_access(super_admin.user_role)
          post :create_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no content status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should not create offboard custom snapshots if admin has no dashboard access' do
        before do
          disable_dashboard_access(admin.user_role)
          allow(controller).to receive(:current_user).and_return(admin)
          post :create_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no content status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create offboard custom snapshots as per manager permission' do
        before do
          employee.update(manager_id: manager.id)
          manager.reload
          allow(controller).to receive(:current_user).and_return(manager)
          post :create_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no context status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create offboard custom snapshots as per employee permission' do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          post :create_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return forbidden status" do
          expect(response.status).to eq(204)
        end
      end
    end

    context 'should create offboard custom snapshots' do
      let(:offboard_user) { create(:offboarded_user, company: company) }
      let(:future_offboard_user) { create(:offboarded_user, termination_date: company.time.to_date + 3.days, current_stage: :last_week, company: company) }
      let(:offboarded_user_with_past_snapshot) { create(:offboarded_user, :user_with_past_snapshot, company: company) }
      let(:offboarded_user_with_future_snapshot) { create(:offboarded_user, :user_with_future_snapshot, current_stage: :last_week, termination_date: 1.days.from_now, company: company) }
      let(:offboard_user_with_current_date) { create(:offboarded_user, :user_with_current_date_snapshot, termination_date: Time.now.in_time_zone(company.time_zone).to_date, company: company) }

      context 'should create offboard custom snapshots if sub_tab is not present' do
        before do
          post :create_offboard_custom_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create offboard custom snapshots as per super admin permission' do
        before do
          post :create_offboard_custom_snapshots, params: { user_id: offboard_user.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create offboard custom snapshots as per admin permission' do
        before do
          allow(controller).to receive(:current_user).and_return(admin)
          post :create_offboard_custom_snapshots, params: { user_id: offboard_user.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create past termination date offboard custom snapshots' do
        before do
          offboard_user.custom_field_values.create(custom_field_id: @custom_field.id, custom_field_option_id: @custom_field_option.id)
          post :create_offboard_custom_snapshots, params: { user_id: offboard_user.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status, effective date value is equal to termination date, is terminated to true, last day worked two days ago, termination type voluntary, eligible for rehire yes and applied status of custom table user snapshot, and snapshot last day worked, termination type, eligible for rehire, value is equal to user and user status is inactive" do
          expect(response.status).to eq(200)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.effective_date).to eq(offboard_user.termination_date)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.is_terminated).to eq(true)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.terminated_data["last_day_worked"].to_date).to eq(2.days.ago.to_date)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.terminated_data["termination_type"]).to eq('voluntary')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.terminated_data["eligible_for_rehire"]).to eq('yes')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.terminated_data["last_day_worked"].to_date).to eq(offboard_user.reload.last_day_worked)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.terminated_data["termination_type"]).to eq(offboard_user.reload.termination_type)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user.id).first.terminated_data["eligible_for_rehire"]).to eq(offboard_user.reload.eligible_for_rehire)
          expect(CustomSnapshot.where(custom_field_id: @custom_field.id, custom_table_user_snapshot_id: offboard_user.custom_table_user_snapshots.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])).first.id).first.custom_field_value.to_i).to eq(@custom_field_option.id)
          expect(offboard_user.state).to eq("inactive")
        end
      end

      context 'should create future termination data offboard custom snapshots' do
        before do
          future_offboard_user.custom_field_values.create(custom_field_id: @custom_field.id, custom_field_option_id: @custom_field_option.id)
          post :create_offboard_custom_snapshots, params: { user_id: future_offboard_user.id, sub_tab: 'dashboard' }, as: :json
        end
        it "should return ok status, effective date value is equal to termination date, is terminated to true, last day worked two days ago, termination type voluntary, eligible for rehire yes, termination date one day from now and queued status of custom table user snapshot, and (snapshot last day worked, termination type, eligible for rehire value is not equal to user) and user status is active" do
          expect(response.status).to eq(200)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.effective_date).to eq(future_offboard_user.termination_date)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.is_terminated).to eq(true)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.terminated_data["last_day_worked"].to_date).to eq(2.days.ago.to_date)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.terminated_data["termination_type"]).to eq('voluntary')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.terminated_data["eligible_for_rehire"]).to eq('yes')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.state).to eq('queue')
          expect(future_offboard_user.termination_date).to eq(company.time.to_date + 3.days)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.terminated_data["last_day_worked"].to_date).to eq(future_offboard_user.reload.last_day_worked)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.terminated_data["termination_type"]).to eq(future_offboard_user.reload.termination_type)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: future_offboard_user.id).first.terminated_data["eligible_for_rehire"]).to eq(future_offboard_user.reload.eligible_for_rehire)
          expect(CustomSnapshot.where(custom_field_id: @custom_field.id, custom_table_user_snapshot_id: future_offboard_user.custom_table_user_snapshots.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])).first.id).first.custom_field_value.to_i).to eq(@custom_field_option.id)
          expect(future_offboard_user.state).to eq("active")
        end
      end

      context 'should change state of previous custom table user snapshot' do
        before do
          offboarded_user_with_past_snapshot.update!(termination_date: 5.days.ago)
          post :create_offboard_custom_snapshots, params: { user_id: offboarded_user_with_past_snapshot.id }, as: :json
        end

        it "should return ok status and change state of previous snapshot to processed" do
          expect(response.status).to eq(200)
          expect(CustomTableUserSnapshot.where(custom_table_id: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]), user_id: offboarded_user_with_past_snapshot.id, effective_date: 5.days.ago.to_date).first.state).to eq('processed')
        end
      end

      context 'should destroy future snapshots during offboarding' do
        it 'should return one future custom table user snapshots before destroying and no future custom table user snapshot after destroying' do
          expect(offboarded_user_with_future_snapshot.custom_table_user_snapshots.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information]).id, state: CustomTableUserSnapshot.states[:queue]).count).to eq(1)
          post :create_offboard_custom_snapshots, params: { user_id: offboarded_user_with_future_snapshot.id }, format: :json
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information]).id, user_id: offboarded_user_with_future_snapshot.id, state: CustomTableUserSnapshot.states[:queue]).count).to eq(0)
        end
      end

      context 'should create offboard custom snapshots of custom table if field display location is offboarding' do
        before do
          @offboard_user_with_custom_table = create(:offboarded_user, :user_with_timeline_custom_table, company: company)
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:general], table_type: CustomTable.table_types[:timeline])
          @phone_field = @custom_table.custom_fields.find_by(field_type: CustomField.field_types[:phone])
          @currency_field = @custom_table.custom_fields.find_by(field_type: CustomField.field_types[:currency])
          @text_field = @custom_table.custom_fields.find_by(field_type: CustomField.field_types[:short_text])
          custom_fields_data_array = [
            {"user_id" => @offboard_user_with_custom_table.id, "custom_field_id" => @phone_field.id, "custom_field_value" =>"USA|121|2212121"},
            {"user_id" => @offboard_user_with_custom_table.id, "custom_field_id" => @currency_field.id, "custom_field_value" => "PKR|200"},
            {"user_id" => @offboard_user_with_custom_table.id, "custom_field_id" => @text_field.id, "custom_field_value" => "ok"}]

          post :create_offboard_custom_snapshots, params: { user_id: @offboard_user_with_custom_table.id, custom_fields_data: custom_fields_data_array }, as: :json
        end

        it 'should check effective date value is equal to termination date applied state of custom table user snapshot and assign phone snapshot value and assign currency snapshot value and assign short text snapshot value' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: @offboard_user_with_custom_table.id).first.effective_date).to eq(@offboard_user_with_custom_table.termination_date)
          expect(@offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
          expect(@offboard_user_with_custom_table.get_custom_field_value_text(@phone_field.name, false, nil, nil, true, @phone_field.id, false, true)).to eq(nil)
          expect( @offboard_user_with_custom_table.get_custom_field_value_text(@currency_field.name, false, nil, nil, true, @currency_field.id, false, true)).to eq(nil)
          expect( @offboard_user_with_custom_table.get_custom_field_value_text(@text_field.name, false, nil, nil, true, @text_field.id, false, true)).to eq(nil)
        end
      end

      context 'should create offboard custom snapshots of custom table for future offboard but not assign value' do
        before do
          @offboard_user_with_custom_table = create(:offboarded_user, :user_with_timeline_custom_table, termination_date: 1.days.from_now, current_stage: :last_week, company: company)
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:general], table_type: CustomTable.table_types[:timeline])
          @phone_field = @custom_table.custom_fields.find_by(field_type: CustomField.field_types[:phone])
          @currency_field = @custom_table.custom_fields.find_by(field_type: CustomField.field_types[:currency])
          @text_field = @custom_table.custom_fields.find_by(field_type: CustomField.field_types[:short_text])
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:general], table_type: CustomTable.table_types[:timeline])
          @offboard_user_with_custom_table.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: @offboard_user_with_custom_table.start_date.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:applied])
          custom_fields_data_array = [
            {"user_id" => @offboard_user_with_custom_table.id, "custom_field_id" => @phone_field.id, "custom_field_value" =>"USA|121|2212121"},
            {"user_id" => @offboard_user_with_custom_table.id, "custom_field_id" => @currency_field.id, "custom_field_value" => "PKR|200"},
            {"user_id" => @offboard_user_with_custom_table.id, "custom_field_id" => @text_field.id, "custom_field_value" => "ok"}]

          post :create_offboard_custom_snapshots, params: { user_id: @offboard_user_with_custom_table.id, custom_fields_data:custom_fields_data_array }, as: :json
        end

        it 'should return queue state, effective date value is equal to termination date, create custom snapshot with phone, currency and short text snapshot value and not assign values' do
          expect(@offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second.state).to eq('queue')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: @offboard_user_with_custom_table.id).second.effective_date).to eq(@offboard_user_with_custom_table.termination_date)
          expect(CustomSnapshot.where(custom_field_id: @phone_field.id, custom_table_user_snapshot_id: @offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value).to eq("USA|121|2212121")
          expect(CustomSnapshot.where(custom_field_id: @currency_field.id, custom_table_user_snapshot_id: @offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value).to eq("PKR|200")
          expect(CustomSnapshot.where(custom_field_id: @text_field.id, custom_table_user_snapshot_id: @offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value).to eq("ok")
          expect(@offboard_user_with_custom_table.get_custom_field_value_text(@phone_field.name, false, nil, nil, true, @phone_field.id, false, true)).not_to eq(CustomSnapshot.where(custom_field_id: @phone_field.id, custom_table_user_snapshot_id: @offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(@offboard_user_with_custom_table.get_custom_field_value_text(@currency_field.name, false, nil, nil, true, @currency_field.id, false, true)).not_to eq(CustomSnapshot.where(custom_field_id: @currency_field.id, custom_table_user_snapshot_id: @offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(@offboard_user_with_custom_table.get_custom_field_value_text(@text_field.name, false, nil, nil, true, @text_field.id, false, true)).not_to eq(CustomSnapshot.where(custom_field_id: @text_field.id, custom_table_user_snapshot_id: @offboard_user_with_custom_table.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
        end
      end

      context 'should create current date offboard custom snapshots' do
        before do
          offboard_user_with_current_date.custom_field_values.create(custom_field_id: @custom_field.id, custom_field_option_id: @custom_field_option.id)
          offboard_user_with_current_date.reload.update!(termination_date: Time.now.in_time_zone(company.time_zone).to_date, last_day_worked: 2.days.ago, termination_type: 'voluntary', eligible_for_rehire: 'yes')
          post :create_offboard_custom_snapshots, params: { user_id: offboard_user_with_current_date.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status, applied state, change state of previous snapshot to processed, effective date value is equal to termination date, is terminated status true, is last day worked two days ago, termination type voluntary, eligible for rehire yes and assign last day worked, termination type, eligible for rehire to user and user state is inactive" do
          expect(response.status).to eq(200)
          expect(CustomTableUserSnapshot.where(custom_table_id: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]), user_id: offboard_user_with_current_date.id, effective_date: Time.now.in_time_zone(company.time_zone).to_date).first.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.effective_date).to eq(offboard_user_with_current_date.termination_date)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.is_terminated).to eq(true)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.terminated_data["last_day_worked"].to_date).to eq(2.days.ago.to_date)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.terminated_data["termination_type"]).to eq('voluntary')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.terminated_data["eligible_for_rehire"]).to eq('yes')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.terminated_data["last_day_worked"].to_date).to eq(offboard_user_with_current_date.reload.last_day_worked)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.terminated_data["termination_type"]).to eq(offboard_user_with_current_date.reload.termination_type)
          expect(CustomTableUserSnapshot.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).id, user_id: offboard_user_with_current_date.id).second.terminated_data["eligible_for_rehire"]).to eq(offboard_user_with_current_date.reload.eligible_for_rehire)
          expect(CustomSnapshot.where(custom_field_id: @custom_field.id, custom_table_user_snapshot_id: offboard_user_with_current_date.custom_table_user_snapshots.where(custom_table_id: company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])).second.id).first.custom_field_value.to_i).to eq(@custom_field_option.id)
          expect(offboard_user.state).to eq("inactive")
        end
      end
    end
  end
end
