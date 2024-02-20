require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :controller do

  let!(:company) { create(:company, enabled_time_off: true) }
  let!(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let!(:tim) { create(:tim, state: :active, current_stage: :registered, company: company) }
  let(:marketing) { create(:team, company: company, name: 'Marketing') }
  let(:santa_clara) { create(:location, company: company, name: 'Santa Clara') }
  let(:valid_session) { {} }
  let(:workspace) { create(:workspace, company: company, name: 'Test Workspace', associated_email: 'workspace@abc.com') }
  let(:workstream) { create(:workstream, company: company) }
  let(:task) { create(:task, workstream: workstream) }
  let!(:new_user) { create(:user, state: :active, current_stage: :registered, start_date: Date.today, company: company)}
  let!(:new_user_offboarded) { create(:user, state: :inactive, current_stage: :departed, start_date: Date.today, company: company)}
  let(:super_admin) { create(:user, company: company) }
  let(:admin) { create(:user, company: company, role: User.roles[:admin]) }
  let(:indirect_manager) { create(:user, company: company, role: User.roles[:employee])}
  let(:manager) { create(:user, company: company, role: User.roles[:employee], manager_id: indirect_manager.id) }
  let(:employee) { create(:user, state: :active, current_stage: :registered, company: company, manager: manager, location: location, team: team, role: User.roles[:employee]) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe '#user_with_pending_ptos' do
    before {User.current = user}
  	let(:nick){ create(:user_with_manager_and_policy, :auto_approval, company: company) }
  	let!(:pto_request){ create(:pto_request, pto_policy: nick.pto_policies.first, user: nick,
  		partial_day_included: false,  user: nick, begin_date: nick.start_date + 2.days,
  		end_date: nick.start_date + 2.days, status: 0) }
  	context 'unauthenticated user' do
  		before do
  		  allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return 401 status' do
  			get :user_with_pending_ptos, params: { id: nick.id }, format: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'accessed by another companys user' do
  		let(:other_company){ create(:company, subdomain: 'mars') }
  		let(:sam){ create(:nick, email: 'sam@mail.com', personal_email: 'sammm@mail.com', company: other_company) }
  		before do

  			allow(controller).to receive(:current_user).and_return(sam)
  		end
  		it 'should return unauthorised status' do
  			get :user_with_pending_ptos, params: { id: nick.id }, format: :json
  			expect(response.status).to eq(204)
  			expect(response.body).to eq("")
  		end
  	end
  	context 'accessed by user of same company' do
  		before do
  		  company.update_column(:enabled_time_off, true)
  		end
  		it 'should return user and pending pto_request' do
  			get :user_with_pending_ptos, params: { id: nick.id }, format: :json
  			expect(response.status).to eq(200)
  			expect(JSON.parse(response.body)["pending_pto_requests"].size).to eq(1)
  			expect(JSON.parse(response.body)["pending_pto_requests"][0].keys).to include('attachments')
  		end
  	end
  end

  describe "PUT #update" do

    it "should update the user's department if exist" do
      put :update, params: { id: tim.id, team_id: marketing.id }, format: :json
      tim.reload
      expect(tim.team_id).to eq(marketing.id)
    end

    it "should update the user's department if does not exist" do
      put :update, params: { id: tim.id, team_id: nil }, format: :json
      tim.reload
      expect(tim.team_id).to eq(nil)
    end

    it "should update the user's first_name" do
      put :update, params: { id: tim.id, first_name: "Kim" }, format: :json
      tim.reload
      expect(tim.first_name).to eq("Kim")
    end

    it "should update the user's last_name" do
      put :update, params: { id: tim.id, last_name: "Krad" }, format: :json
      tim.reload
      expect(tim.last_name).to eq("Krad")
    end

    it "should update the user's preferred_name" do
      put :update, params: { id: tim.id, preferred_name: "Lee" }, format: :json
      tim.reload
      expect(tim.preferred_name).to eq("Lee")
    end

    it "should update the user's email" do
      put :update, params: { id: tim.id, email: "tim@testing.com" }, format: :json
      tim.reload
      expect(tim.email).to eq("tim@testing.com")
    end

    it "should update the user's start_date" do
      put :update, params: { id: tim.id, start_date: Date.today }, format: :json
      tim.reload
      expect(tim.start_date).to eq(Date.today)
    end

    it "should update the user's location if exist" do
      put :update, params: { id: tim.id, location_id: santa_clara.id }, format: :json
      tim.reload
      expect(tim.location_id).to eq(santa_clara.id)
    end

    it "should update the user's location if does not exist" do
      put :update, params: { id: tim.id, location_id: nil }, format: :json
      tim.reload
      expect(tim.location_id).to eq(nil)
    end

    it "should update the user job title" do
      put :update, params: { id: tim.id, title: "Manager" }, format: :json
      tim.reload
      expect(tim.title).to eq("Manager")
    end

  end

  describe "fetch overdue tasks" do

    it "should fetch tasks having owner as user himself" do
      task_connection = FactoryGirl.create(:task_user_connection, task: task, owner: user, due_date: "2017-09-28")
      result = get :get_my_activities_count, params: { id: user.id }
      response = JSON.parse result.body
      expect(response["overdue_tasks_count"]).to eq(1)
    end

    it "should not fetch tasks having owner as workspace" do
      task_connection = FactoryGirl.create(:task_user_connection, task: task, owner: user, due_date: "2017-09-28", workspace: workspace, owner_type: 1)
      result = get :get_my_activities_count, params: { id: user.id }
      response = JSON.parse result.body
      expect(response["overdue_tasks_count"]).to eq(0)
    end
  end

  describe "fetch new arrivals paginated" do
    before(:each) do
      @onboarded_user_ids = User.where(current_stage: :registered).ids
    end

    it "should fetch all the users in onboarding stage People" do
      result = get :paginated, params: {active_employees: true, basic: true, company_id: company.id}, format: :json
      response = JSON.parse result.body
      expect(response['meta']['count']).to eq(@onboarded_user_ids.count)
      expect(@onboarded_user_ids).to include(*response['users'].map{|u| u['id']})
      expect(response['users'][0].keys.count).to eq(35)
    end

    it "should fetch all the users in onboarding stage NewArrival" do
      result = get :paginated, params: {active_employees: true, new_arrivals: true, company_id: company.id}, format: :json
      response = JSON.parse result.body
      expect(response["meta"]["count"]).to eq(1)
      expect(response["users"][0].keys.count).to eq(10)
    end

    it "should fetch all the users in onboarding stage Dashboard" do
      result = get :paginated, params: {active_employees: true, company_id: company.id}, format: :json
      response = JSON.parse result.body
      expect(response['meta']['count']).to eq(@onboarded_user_ids.count)
      expect(@onboarded_user_ids).to include(*response['users'].map{|u| u['id']})
      expect(response['users'][0].keys.count).to eq(45)
    end

  end

  describe 'POST #manager_form_snapshot_creation' do
    let!(:employee) {create(:user_with_manager_form_field, role: User.roles[:employee], company: company, manager_id: manager.id)}

    before do
      company.update(time_zone: 'UTC')
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context 'should not create manager form custom snapshots' do
      context 'should not create manager form custom snapshots for unauthenticated user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :manager_form_snapshot_creation, params: { id: super_admin.id, snapshots_data: [{user_id: super_admin.id, custom_field_value: "SE", custom_field_id: 'jt'}]}, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context 'should not create manager form custom snapshots for other company' do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          post :manager_form_snapshot_creation, params: { id: other_user.id, snapshots_data: [{user_id: other_user.id, custom_field_value: "SE", custom_field_id: 'jt'}]}, format: :json
          expect(response.status).to eq(204)
        end

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)
          post :manager_form_snapshot_creation, params: { id: other_user.id, snapshots_data: [{user_id: other_user.id, custom_field_value: "SE", custom_field_id: 'jt'}]}, format: :json
          expect(response.status).to eq(204)
        end
      end

      context 'should not create manager form custom snapshots for employee user' do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          post :manager_form_snapshot_creation, params: { id: super_admin.id, snapshots_data: [{user_id: super_admin.id, custom_field_value: "SE", custom_field_id: 'jt'}]}, format: :json
        end

        it 'should return no content status' do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create manager form custom snapshots for indirect manager' do
        before do
          manager.reload
          indirect_manager.reload
          allow(controller).to receive(:current_user).and_return(indirect_manager)
          post :manager_form_snapshot_creation, params: { id: employee.id, snapshots_data: [{user_id: employee.id, custom_field_value: "SE", custom_field_id: 'jt'}]}, format: :json
        end

        it 'should return no content status' do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create manager form custom snapshots for admin user' do
        before do
          allow(controller).to receive(:current_user).and_return(admin)
          post :manager_form_snapshot_creation, params: { id: employee.id, snapshots_data: [{user_id: employee.id, custom_field_value: "SE", custom_field_id: 'jt'}]}, format: :json
        end

        it 'should return no content status' do
          expect(response.status).to eq(204)
        end
      end
    end

    context 'should create manager form custom snapshots' do
      context 'should create manager form custom snapshots for direct manager' do
        before do
          manager.reload
          allow(controller).to receive(:current_user).and_return(manager)
          @custom_table = employee.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:general], table_type: CustomTable.table_types[:timeline])
          @custom_fields = @custom_table.custom_fields
          post :manager_form_snapshot_creation, params: { id: employee.id, snapshots_data: [{user_id: employee.id, custom_field_value: 'USD|325.00', custom_field_id: @custom_fields.find_by(field_type: 'currency').id}, {user_id: employee.id, custom_field_value: 'USA|454|8887484', custom_field_id: @custom_fields.find_by(field_type: 'phone').id}]}, format: :json
        end

        it 'should return ok status, assign effective date value, currency field value, international phone value to user' do
          expect(response.status).to eq(200)
          expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(name: 'Effective Date').id, false, true)).to eq(CustomSnapshot.where(custom_field_id: @custom_fields.find_by(name: 'Effective Date').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value.to_date.to_s)
          expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(field_type: 'currency').id, false, true)).to eq(CustomSnapshot.where(custom_field_id:  @custom_fields.find_by(field_type: 'currency').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)
          expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(field_type: 'phone').id, false, true)).to eq(CustomSnapshot.where(custom_field_id: @custom_fields.find_by(field_type: 'phone').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)
        end
      end

      context 'should create manager form custom snapshots for super admin user' do
        before do
          allow(controller).to receive(:current_user).and_return(super_admin)
          @custom_table = employee.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:general], table_type: CustomTable.table_types[:timeline])
          @custom_fields = @custom_table.custom_fields
          post :manager_form_snapshot_creation,params: {  id: employee.id, snapshots_data: [{user_id: employee.id, custom_field_value: 'USD|325.00', custom_field_id: @custom_fields.find_by(field_type: 'currency').id}, {user_id: employee.id, custom_field_value: 'USA|454|8887484', custom_field_id: @custom_fields.find_by(field_type: 'phone').id}]}, format: :json
        end

        it 'should return ok status, assign effective date value to user' do
          expect(response.status).to eq(200)
          expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(name: 'Effective Date').id, false, true)).to eq(CustomSnapshot.where(custom_field_id: @custom_fields.find_by(name: 'Effective Date').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value.to_date.to_s)
          expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(field_type: 'currency').id, false, true)).to eq(CustomSnapshot.where(custom_field_id:  @custom_fields.find_by(field_type: 'currency').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)
          expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(field_type: 'phone').id, false, true)).to eq(CustomSnapshot.where(custom_field_id: @custom_fields.find_by(field_type: 'phone').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)
        end
      end
    end

    context 'should create new custom table user snapshot' do
      let!(:employee) {create(:with_manager_form_custom_snapshots, role: User.roles[:employee], company: company)}

      before do
        @custom_table = employee.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:general], table_type: CustomTable.table_types[:timeline])
        @custom_fields = @custom_table.custom_fields
        @custom_fields.each do |custom_field|
          create(:custom_snapshot, custom_field_id: custom_field.id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.find_by(custom_table_id: @custom_table.id).id, custom_field_value: 200)
        end
        post :manager_form_snapshot_creation, params: { id: employee.id, snapshots_data: [{user_id: employee.id, custom_field_value: 'USD|325.00', custom_field_id: @custom_fields.find_by(field_type: 'currency').id}, {user_id: employee.id, custom_field_value: 'USA|454|8887484', custom_field_id: @custom_fields.find_by(field_type: 'phone').id}]}, format: :json
      end

      it 'should create another custom table user snapshot of that user, four custom snapshots of custom table user snapshot, assign effective date value, currency custom field custom snapshot value, international phone custom field custom snapshot value to user' do
        expect(employee.custom_table_user_snapshots.count).to eq(2)
        expect(CustomSnapshot.where(custom_table_user_snapshot: employee.custom_table_user_snapshots.first.id).count).to eq(4)
        expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(name: 'Effective Date').id, false, true)).to eq(CustomSnapshot.where(custom_field_id: @custom_fields.find_by(name: 'Effective Date').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).order(id: :desc).first.id).first.custom_field_value.to_date.to_s)
        expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(field_type: 'currency').id, false, true)).to eq(CustomSnapshot.where(custom_field_id:  @custom_fields.find_by(field_type: 'currency').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).order(id: :desc).first.id).first.custom_field_value)
        expect(employee.get_custom_field_value_text('', false, nil, nil, true, @custom_fields.find_by(field_type: 'phone').id, false, true)).to eq( CustomSnapshot.where(custom_field_id: @custom_fields.find_by(field_type: 'phone').id, custom_table_user_snapshot_id: employee.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).order(id: :desc).first.id).first.custom_field_value)
      end
    end
  end

  describe 'PUT #update to check ADP integration' do
    context 'can make ADP-US update call' do

      before do
        create(:adp_wfn_us_integration, company: company)
        @adp_us_user = create(:user, state: :active, current_stage: :registered, company: company)
        @adp_us_user.update_column(:adp_wfn_us_id, 123)

      end

      it 'should make update call for first name change' do
        expect{
          put :update, params: {id: @adp_us_user.id, first_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for last name change' do
        expect{
          put :update, params: {id: @adp_us_user.id, last_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for preferred name change' do
        expect{
          put :update, params: {id: @adp_us_user.id, preferred_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for personal email change' do
        expect{
          put :update, params: {id: @adp_us_user.id, personal_email: 'testadpus@test.com'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for email change' do
        expect{
          put :update, params: {id: @adp_us_user.id, email: 'testadpus@test.com'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for title change' do
        expect{
          put :update, params: {id: @adp_us_user.id, title: 'SE'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end
    end

    context 'can make ADP-CAN update call' do

      before do
        create(:adp_wfn_can_integration, company: company)
        @adp_can_user = create(:user, state: :active, current_stage: :registered, company: company)
        @adp_can_user.update_column(:adp_wfn_can_id, 123)

      end

      it 'should make update call for first name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, first_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for last name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, last_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for preferred name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, preferred_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for personal email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, personal_email: 'testadpus@test.com'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, email: 'testadpus@test.com'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for title change' do
        expect{
          put :update, params: {id: @adp_can_user.id, title: 'SE'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end
    end

    context 'can not make ADP update call' do

      before do
        @adp_can_user = create(:user, state: :active, current_stage: :registered, company: company)
        @adp_can_user.update_column(:adp_wfn_can_id, 123)

      end

      it 'should make update call for first name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, first_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for last name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, last_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for preferred name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, preferred_name: 'Test'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for personal email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, personal_email: 'testadpus@test.com'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, email: 'testadpus@test.com'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for title change' do
        expect{
          put :update, params: {id: @adp_can_user.id, title: 'SE'}, format: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end
    end
  end

  context 'index' do
    it 'should return users if current user is of same company' do
      get :index, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).count).to_not eq(0)
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :index, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :index, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :index, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'mentions_index' do
    it 'should return users mentioned user' do
      get :mentions_index,params: { mention_query: tim.first_name}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(tim.id)).to eq(true)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(user.id)).to eq(false)
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :mentions_index, params: {mention_query: tim.first_name}, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :mentions_index, params: {mention_query: tim.first_name}, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :mentions_index, params: {mention_query: tim.first_name}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'mentioned_users' do
    it 'should return only mentioned user' do
      get :mentioned_users, params: {users: [tim.id]}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(tim.id)).to eq(true)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(user.id)).to eq(false)
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :mentioned_users, params: {users: [tim.id]}, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :mentioned_users, params: {users: [tim.id]}, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :mentioned_users, params: {users: [tim.id]}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'basic_search' do
    it 'should return only searched user' do
      get :basic_search, params: {term: tim.first_name}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(tim.id)).to eq(true)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(user.id)).to eq(false)
    end

    it 'should return only searched user of organization chart' do
      tim.update(title: 'CEO')
      get :basic_search, params: {term: tim.first_name, organization_chart_users: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(tim.id)).to eq(true)
    end

    it 'should not return user which is not part of organization chart' do
      get :basic_search, params: {term: tim.first_name, organization_chart_users: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(tim.id)).to eq(false)
    end

    it 'should return only manager users' do
      new_user.update(manager_id: tim.id)
      get :basic_search, params: {term: tim.first_name, manager_users_only: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(tim.id)).to eq(true)
    end

    it 'should not return other users' do
      u = create(:user, company: company)
      get :basic_search, params: {term: u.first_name, organization_chart_users: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(u.id)).to eq(false)
    end
  end

  context 'user_algolia_mock' do
    it 'should return all users' do
      get :user_algolia_mock, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).count).to eq(company.users.count)
    end

    it 'should not return any user' do
      Rails.env.stub(:test?) {false}
      get :user_algolia_mock, format: :json
      expect(response.status).to eq(200)
      expect(response.body).to eq("")
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :user_algolia_mock, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :user_algolia_mock, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :user_algolia_mock, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'basic' do
    it 'should return only searched user' do
      get :basic,params: { term: tim.first_name}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(tim.id)).to eq(true)
      expect(JSON.parse(response.body).map{|u| u['id']}.include?(user.id)).to eq(false)
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :basic,params: { term: tim.first_name}, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :basic,params: { term: tim.first_name}, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :basic,params: { term: tim.first_name}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'show' do
    it 'should return full user' do
      get :show, params: {id: tim.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(95)
    end

    it 'should return light user' do
      get :show, params: {id: tim.id, permission_light: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(11)
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :show, params: {id: tim.id}, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :show, params: {id: tim.id}, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :show, params: {id: tim.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'home_user' do
    it 'should return home_user user' do
      policy = FactoryGirl.create(:default_pto_policy, company: company, is_enabled: false)
      Sidekiq::Testing.inline! {policy.update(is_enabled: true)}
      get :home_user, params: {id: tim.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(61)
    end

    it 'should return light user' do
      get :home_user, params: {id: tim.id, light: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(50)
    end

    it 'should return profile user' do
      get :home_user, params: {id: tim.id, profile_page: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(57)
    end

    it 'should return task user' do
      get :home_user, params: {id: tim.id, task_page: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(35)
    end

    it 'should return document_page user' do
      get :home_user, params: {id: tim.id, document_page: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(33)
    end

    it 'should return role user' do
      get :home_user, params: {id: tim.id, role_page: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(37)
    end

    it 'should return calendar_page user' do
      get :home_user, params: {id: tim.id, calendar_page: true}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body).keys.count).to eq(32)
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :home_user, params: {id: tim.id}, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :home_user, params: {id: tim.id}, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :home_user, params: {id: tim.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'user_with_pto_policies' do
    let(:nick) {create(:user_with_manager_and_policy, company: company)}
    it 'should return user with pto_policies' do
      get :user_with_pto_policies, params: {id: nick.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(nick.id)
      expect(JSON.parse(response.body)['pto_policies'].first['id']).to eq(nick.pto_policies.first.id)
    end

    it 'should return policies if not present' do
      get :user_with_pto_policies, params: {id: tim.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['id']).to eq(tim.id)
      expect(JSON.parse(response.body)['pto_policies']).to eq([])
    end

    it 'should not return users if current user is of same company' do
      allow(controller).to receive(:current_user).and_return(create(:user))
      get :user_with_pto_policies, params: {id: tim.id}, format: :json
      expect(response.status).to eq(204)
    end

    it 'should not return users if current user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :user_with_pto_policies, params: {id: tim.id}, format: :json
      expect(response.status).to eq(401)
    end

    it 'should not return users if company is nil' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :user_with_pto_policies, params: {id: tim.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'email_availibility' do
    it 'should return true if email already exists' do
      company.stub(:provisioning_integration_url) {'test.com'}
      get :email_availibility, params: {username: 'tim'}, format: :json
      expect(JSON.parse(response.body)['email_exists']).to eq(true)
    end

    it 'should return false if email do not exists' do
      company.stub(:provisioning_integration_url) {'test.com'}
      get :email_availibility, params: {username: 'tim'}, format: :json
      expect(JSON.parse(response.body)['email_exists']).to eq(true)
    end
  end

  context 'people_paginated_count' do
    it 'should return the people_paginated_count' do
      get :people_paginated_count, format: :json
      expect(JSON.parse(response.body)['totalPeople']).to eq(4)
      expect(response.status).to eq(200)
    end

    it 'should not return the people_paginated_count' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :people_paginated_count, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'total_active_count' do
    it 'should return the total_active_count' do
      get :total_active_count, format: :json
      expect(JSON.parse(response.body)['activePeople']).to eq(3)
      expect(response.status).to eq(200)
    end

    it 'should not return the total_active_count' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :total_active_count, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'dashboard_people_count' do
    let(:onboard_user) { create(:user, company: company)}
    it 'should return the dashboard_people_count' do
      onboard_user.update(outstanding_tasks_count: 1, current_stage: 'invited')
      new_user.update(current_stage: 'departed', termination_date: 14.days.ago)
      get :dashboard_people_count, params: {"offboard_params"=>"{\"all_departures\":true,\"dashboard_search\":true,\"sort_column\":\"last_day_worked\",\"sort_order\":\"desc\",\"start\":0,\"sub_tab\":\"dashboard\",\"company_id\":#{company.id},\"count\":true}", "onboard_params"=>"{\"dashboard_search\":true,\"recent_employees\":true,\"sort_column\":\"start_date\",\"sort_order\":\"desc\",\"start\":0,\"sub_tab\":\"dashboard\",\"tuc_state\":true,\"company_id\":#{company.id},\"count\":true}"}, format: :json
      expect(JSON.parse(response.body)['onboard_count']).to eq(1)
      expect(JSON.parse(response.body)['offboard_count']).to eq(1)
      expect(response.status).to eq(200)
    end

    it 'should not return the dashboard_people_count' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :dashboard_people_count, params: {"offboard_params"=>"{\"all_departures\":true,\"dashboard_search\":true,\"sort_column\":\"last_day_worked\",\"sort_order\":\"desc\",\"start\":0,\"sub_tab\":\"dashboard\",\"company_id\":#{company.id},\"count\":true}", "onboard_params"=>"{\"dashboard_search\":true,\"recent_employees\":true,\"sort_column\":\"start_date\",\"sort_order\":\"desc\",\"start\":0,\"sub_tab\":\"dashboard\",\"tuc_state\":true,\"company_id\":#{company.id},\"count\":true}"}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'activities_count' do
    let(:workstream) { create(:workstream, company: user.company) }
    let(:task)  {create(:task, workstream: workstream)}
    let!(:task_user_connection)  {create(:task_user_connection, owner: user, user: user, task: task, due_date: 3.days.ago)}

    it 'should return the activities_count' do
      get :activities_count, format: :json
      body = JSON.parse(response.body)
      expect(body.keys.include?('open_activities_count')).to eq(true)
      expect(body.keys.include?('open_activities_user_count')).to eq(true)
      expect(body.keys.include?('overdue_activities_count')).to eq(true)
      expect(body.keys.include?('overdue_activities_user_count')).to eq(true)
      expect(body['open_activities_count']).to eq(1)
      expect(body['open_activities_user_count']).to eq(1)
      expect(body['overdue_activities_count']).to eq(1)
      expect(body['overdue_activities_user_count']).to eq(1)
      expect(response.status).to eq(200)
    end

    it 'should not return the activities_count' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :activities_count, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'get_my_activities_count' do
    let(:workstream) { create(:workstream, company: user.company) }
    let(:task)  {create(:task, workstream: workstream)}
    let!(:task_user_connection)  {create(:task_user_connection, owner: user, user: user, task: task, due_date: 3.days.ago)}

    it 'should return the get_my_activities_count' do
      get :get_my_activities_count, params: {id: user.id}, format: :json
      body = JSON.parse(response.body)
      expect(body.keys.include?('active_tasks_count')).to eq(true)
      expect(body.keys.include?('documents_count')).to eq(true)
      expect(body.keys.include?('overdue_tasks_count')).to eq(true)
      expect(body.keys.include?('leave_requests_count')).to eq(true)
      expect(body['active_tasks_count']).to eq(1)
      expect(body['documents_count']).to eq(0)
      expect(body['overdue_tasks_count']).to eq(1)
      expect(body['leave_requests_count']).to eq(0)
      expect(response.status).to eq(200)
    end

    it 'should not return the get_my_activities_count' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :get_my_activities_count, params: {id: user.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'get_team_activities_count' do
    it 'should return the get_team_activities_count' do
      get :get_team_activities_count, params: {id: user.id}, format: :json
      expect(JSON.parse(response.body).keys.include?('incomplete_activities_count')).to eq(true)
      expect(JSON.parse(response.body)['incomplete_activities_count']).to eq(0)
      expect(response.status).to eq(200)
    end

    it 'should not return the get_team_activities_count' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :get_team_activities_count, params: {id: user.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'people_paginated' do
    it 'should return the people_paginated without term' do
      get :people_paginated, params: {"draw"=>"1", "columns"=>{"0"=>{"data"=>"selects", "name"=>"",
        "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
        "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true",
        "search"=>{"value"=>"", "regex"=>"false"}}, "2"=>{"data"=>"", "name"=>"",
        "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
        "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true",
        "search"=>{"value"=>"", "regex"=>"false"}}, "4"=>{"data"=>"", "name"=>"",
        "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
        "5"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true",
        "search"=>{"value"=>"", "regex"=>"false"}}, "6"=>{"data"=>"", "name"=>"",
        "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
        "7"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false",
        "search"=>{"value"=>"", "regex"=>"false"}}}, "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}},
        "start"=>"0", "length"=>"25", "search"=>{"value"=>"", "regex"=>"false"}, "people"=>"true",
        "registered"=>"true", "name_title_search"=>"true", "company_id"=>user.company_id, "page"=>1,
        "per_page"=>25, "order_column"=>"preferred_full_name", "order_in"=>"asc", "term"=>nil}, format: :json
      body = JSON.parse(response.body)
      expect(body.keys.include?('draw')).to eq(true)
      expect(body.keys.include?('recordsTotal')).to eq(true)
      expect(body.keys.include?('recordsFiltered')).to eq(true)
      expect(body.keys.include?('data')).to eq(true)
      expect(body['draw']).to eq(1)
      expect(body['recordsTotal']).to eq(2)
      expect(body['recordsFiltered']).to eq(2)
      expect(body['data'].count).to eq(2)
      expect(body['data'].map{ |d| d['id']}.include?(tim.id)).to eq(true)
      expect(body['data'].map{ |d| d['id']}.include?(new_user.id)).to eq(true)
      expect(response.status).to eq(200)
    end

    it 'should return the people_paginated with term' do
      get :people_paginated, params: {"draw"=>"1", "columns"=>{"0"=>{"data"=>"selects", "name"=>"",
        "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
        "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true",
        "search"=>{"value"=>"", "regex"=>"false"}}, "2"=>{"data"=>"", "name"=>"", "searchable"=>"true",
        "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}, "3"=>{"data"=>"", "name"=>"",
        "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
        "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"",
        "regex"=>"false"}}, "5"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true",
        "search"=>{"value"=>"", "regex"=>"false"}}, "6"=>{"data"=>"", "name"=>"", "searchable"=>"true",
        "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}, "7"=>{"data"=>"", "name"=>"",
        "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
        "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"25",
        "search"=>{"value"=>"", "regex"=>"false"},"registered"=>"true",
        "name_title_search"=>"true", "company_id"=>user.company_id, "page"=>1, "per_page"=>25,
        "order_column"=>"preferred_full_name", "order_in"=>"asc", "team" => true, "term"=> nil}, format: :json
      body = JSON.parse(response.body)
      expect(body.keys.include?('draw')).to eq(true)
      expect(body.keys.include?('recordsTotal')).to eq(true)
      expect(body.keys.include?('recordsFiltered')).to eq(true)
      expect(body.keys.include?('data')).to eq(true)
      expect(body['draw']).to eq(1)
      expect(body['recordsTotal']).to eq(3)
      expect(body['recordsFiltered']).to eq(3)
      expect(body['data'].count).to eq(3)
      expect(body['data'].map{ |d| d['id']}.include?(tim.id)).to eq(true)
      expect(body['data'].map{ |d| d['id']}.include?(new_user.id)).to eq(true)
      expect(response.status).to eq(200)
    end

    it 'should not return the people_paginated' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :people_paginated, params: {"draw"=>"1", "columns"=>{"0"=>{"data"=>"selects", "name"=>"",
        "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
        "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true",
        "search"=>{"value"=>"", "regex"=>"false"}}, "2"=>{"data"=>"", "name"=>"", "searchable"=>"true",
        "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}, "3"=>{"data"=>"", "name"=>"",
        "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
        "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"",
        "regex"=>"false"}}, "5"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true",
        "search"=>{"value"=>"", "regex"=>"false"}}, "6"=>{"data"=>"", "name"=>"", "searchable"=>"true",
        "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}, "7"=>{"data"=>"", "name"=>"",
        "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
        "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"25",
        "search"=>{"value"=>"", "regex"=>"false"},"registered"=>"true",
        "name_title_search"=>"true", "company_id"=>user.company_id, "page"=>1, "per_page"=>25,
        "order_column"=>"preferred_full_name", "order_in"=>"asc", "team" => true, "term"=> nil}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'home_group_paginated' do
    it 'should return home_group_paginated' do
      get :home_group_paginated, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['users'].count).to eq(4)
    end

    it 'should not return the home_group_paginated' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :home_group_paginated, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'download_all_documents' do
    it 'should download_all_documents' do
      get :download_all_documents, params: {id: user.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).keys == ['url_key', 'url']).to eq(true)
    end

    it 'should not download_all_documents if company not present' do
      allow(controller).to receive(:current_company).and_return(nil)
      put :download_all_documents, params: {id: user.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'view_all_documents' do
    let!(:document_connection) {create(:user_document_connection, user: user, state: 'completed')}
    let!(:file) {create(:document_upload_request_file)}
    it 'should return empty array for view_all_documents' do
      get :view_all_documents, params: {id: user.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['urls']).to eq([])
    end

    it 'should return urls for view_all_documents' do
      document_connection.attached_files << file
      get :view_all_documents, params: {id: user.id, user_document_connection_id: [document_connection.id]}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['urls'].count).to_not eq(0)
    end

    it 'should not send ursl for view_all_documents if company not present' do
      allow(controller).to receive(:current_company).and_return(nil)
      put :view_all_documents, params: {id: user.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'download_profile_image' do
    it 'should download_profile_image' do
      get :download_profile_image, params: {id: tim.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).keys == ['url']).to eq(true)
    end

    it 'should not download_profile_image if company not present' do
      allow(controller).to receive(:current_company).and_return(nil)
      put :download_profile_image, params: {id: tim.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'get_organization_chart' do
    it 'should get_organization_chart' do
      Sidekiq::Testing.inline! {company.update(organization_root: user, enabled_org_chart: true)}
      get :get_organization_chart, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).keys == ['org_root_present', 'tree']).to eq(true)
    end

    it 'should not get_organization_chart if company not present' do
      allow(controller).to receive(:current_company).and_return(nil)
      put :get_organization_chart,  format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'get_parent_ids' do
    it 'should get_parent_ids' do
      get :get_parent_ids, params: {id: user.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).keys == ['parent_ids']).to eq(true)
    end
  end

  context 'profile_fields_history' do
    it 'should profile_fields_history' do
      get :profile_fields_history, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body) == ["about_you", "facebook", "twitter", "linkedin", "github"]).to eq(true)
    end

    it 'should not profile_fields_history if company not present' do
      allow(controller).to receive(:current_company).and_return(nil)
      put :profile_fields_history,  format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'update_notification' do
    it 'should update_notification' do
      get :update_notification, params: {id: user.id, slack_notification: true, email_notification: true}, format: :json
      expect(response.status).to eq(200)
      expect(user.reload.slack_notification).to eq(true)
      expect(user.reload.email_notification).to eq(true)
    end
    it 'should not update_notification if company not present' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :update_notification, params: {id: user.id, slack_notification: true, email_notification: true}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'get_notification_settings' do
    it 'should get_notification_settings' do
      get :get_notification_settings, params: {id: user.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).keys).to eq(["id", "slack_notification", "email_notification"])
    end
    it 'should not get_notification_settings if company not present' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :get_notification_settings, params: {id: user.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'get_reassign_manager_activities_count' do
    before {User.current = user}
    let!(:manager) { create(:user, company: company, role: User.roles[:employee])}
    let!(:user) { create(:user_with_manager_and_policy, state: :active, current_stage: :registered, company: company, manager:manager) }
    let!(:doc) { create(:document, company: company) }
    let!(:paperwork_request) { create(:paperwork_request, :request_skips_validate, document: doc, user: user, co_signer_id: manager.id, co_signer_type: PaperworkRequest.co_signer_types[:manager], state: "signed") }
    let!(:paperwork_template) { create(:paperwork_template, :template_skips_validate, document: doc, user: user, is_manager_representative: true, company: company) }
    let!(:pto_request){ create(:pto_request, pto_policy: user.pto_policies.first, user: user,
      partial_day_included: false,  user: user, begin_date: user.start_date + 2.days,
      end_date: user.start_date + 2.days, status: 0) }
    let!(:task){ create(:task, task_type: Task.task_types[:manager])}
    let!(:task_user_connection){ create(:task_user_connection, task: task, user: user, state: 'in_progress', owner_id: manager.id)}
    
    it 'should get document count' do
      get :reassign_manager_activities_count, params: {user_id: user.id, previous_manager_id: manager.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['documents_count']).to eq(1)
    end
    
    it 'should get time_off count' do
      get :reassign_manager_activities_count, params: {user_id: user.id, previous_manager_id: user.manager_id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['time_off_count']).to eq(1)
    end
    
    it 'should get tasks count' do
      get :reassign_manager_activities_count, params: {user_id: user.id, previous_manager_id: manager.id}, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['task_count']).to eq(1)      
    end
    
    it 'should not get_reassign_manager_activities_count' do
      allow(controller).to receive(:current_company).and_return(nil)
      get :reassign_manager_activities_count, params: {user_id: user.id, previous_manager_id: manager.id}, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'create job to assign manager activities' do
    let!(:company) { create(:company) }
    let!(:manager) { create(:user, company: company, role: User.roles[:employee])}
    let!(:user) { create(:user_with_manager_and_policy, state: :active, current_stage: :registered, company: company, manager:manager) }
    
    before(:each) do
      @default_queue_size = Sidekiq::Queues["default"].size
    end

    it 'should enque job to assign manager activities' do
      post :reassign_manager_activities, params: { company: company, user_id: user.id, previous_manager_id: manager.id }, format: :json
      expect(Sidekiq::Queues["default"].size).to eq(@default_queue_size + 1)
    end

    it 'should not enque job to assign manager activities if user_id is not present' do
      post :reassign_manager_activities, params: { company: company, user_id: nil, previous_manager_id: manager.id }, format: :json
      expect(Sidekiq::Queues["default"].size).to eq(@default_queue_size)
    end

    it 'should not enque job to assign manager activities if previous_manager_id is not present' do
      post :reassign_manager_activities, params: { company: company, user_id: user.id, previous_manager_id: nil }, format: :json
      expect(Sidekiq::Queues["default"].size).to eq(@default_queue_size)
    end
  end

  context 'get heap data' do
    it 'should return heap data' do
      get :get_heap_data, params: { id: user.id }, format: :json
      expect(response.status).to eq(200)
    end

    it 'should return permissions in normalized form' do
      get :get_heap_data, params: { id: user.id }, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['permissions'].values).to all( be_an(String) )
    end

    it 'should return company properties as hash' do
      get :get_heap_data, params: { id: user.id }, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['company']).to be_an_instance_of(Hash)
    end

    it 'should not return heap data' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :get_heap_data, params: { id: user.id }, format: :json
      expect(response.status).to eq(401)
    end
  end

end
