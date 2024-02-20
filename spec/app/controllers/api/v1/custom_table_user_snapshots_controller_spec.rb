require 'rails_helper'
require "cancan/matchers"

RSpec.describe Api::V1::CustomTableUserSnapshotsController, type: :controller do
  let(:company) { create(:company) }
  let(:employee) { create(:user, company: company, role: 'employee') }
  let(:employee_2) { create(:user, company: company, role: 'employee') }
  let(:manager) { create(:user, company: company, role: 'employee') }
  let(:admin) { create(:user, company: company, role: 'admin') }
  let(:super_admin) { create(:user, company: company) }
  let (:timeline_custom_table_a) { create(:custom_table, company: company, table_type: CustomTable.table_types[:timeline], name: 'Timeline CustomTable A') }
  let(:user) { create(:user, company: company) }

  before do
    employee.update!(manager_id: manager.id)
    manager.reload
    allow(controller).to receive(:current_company).and_return(company)
    allow(controller).to receive(:current_user).and_return(super_admin)
  end

  describe '#user_approval_snapshot_min_date' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    context 'accessibility' do
      it 'should deny access to employee' do
        user.update_column(:role, 0)
        response = get :user_approval_snapshot_min_date, params: { user_array: "{\"userIdArray[]\":[9,10]}" }, as: :json
        expect(response.status).to eq(403)
      end
      it 'should allow access to admin' do
        user.update_column(:role, 1)
        response = get :user_approval_snapshot_min_date, params: { user_array: "{\"userIdArray[]\":[9,10]}" }, as: :json
        expect(response.status).to eq(200)
      end
      it 'should allow access to account_owner' do
        response = get :user_approval_snapshot_min_date, params: { user_array: "{\"userIdArray[]\":[9,10]}" }, as: :json
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#mass_create' do
    let(:custom_field) { create(:custom_field, company: company, field_type: 0) }
    let(:custom_table) { create(:custom_table, company: company, table_type: CustomTable.table_types[:standard]) }
    let(:time_line_table) { create(:custom_table, name: 'timeline table', company: company, table_type: CustomTable.table_types[:timeline]) }
    let(:approval_table)  { create(:approval_custom_table, name: 'approval table', company: company, table_type: CustomTable.table_types[:timeline], is_approval_required: true, approval_expiry_time: 5, approval_chains_attributes: [{ approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1']}]) }

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    context 'without effective_date' do
      it 'schedules a background job' do
        Sidekiq::Testing.fake! do
          expect{
            post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: custom_table.id] }, as: :json
          }.to change(CustomTables::PowerUpdateWorker.jobs, :size).by(1)
        end
      end

      it 'returns a status of 200' do
        response = post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: custom_table.id] }, as: :json
        expect(JSON.parse(response.body)["status"]).to eq(200)
      end

      it 'creates ctus for user' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: custom_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.size).to eq(1)
      end

      it 'creates ctus for the correct custom_table' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: custom_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.first.custom_table_id).to eq(custom_table.id)
      end

      it 'creates ctus with applied state if no previous ctus exists' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: custom_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.first.state).to eq("applied")
      end
    end
    context 'with effective_date' do
      it 'creates ctus with applied if no snapshot exists' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: time_line_table.id, effective_date: company.time.to_date] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.first.state).to eq("applied")
      end

      context 'with existing ctus of past' do
        before do
          user.custom_table_user_snapshots.create(custom_table: time_line_table, effective_date: company.time.to_date - 2.days, state: 'queue')
        end
        it 'creates a new ctus with state queue if effective_date is of future' do
          Sidekiq::Testing.inline! do
            post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: time_line_table.id, effective_date: company.time.to_date + 1.days] }, as: :json
          end
          expect(user.custom_table_user_snapshots.last.state).to eq('queue')
        end
        it 'creates a new ctus with state applied if effective_date is of past' do
          Sidekiq::Testing.inline! do
            post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: time_line_table.id, effective_date: company.time.to_date - 1.days] }, as: :json
          end
          expect(user.custom_table_user_snapshots.last.state).to eq('applied')
        end
      end

      context 'with existing ctus of future' do
        before do
          user.custom_table_user_snapshots.create(custom_table: time_line_table, effective_date: company.time.to_date + 8.days, state: 'queue')
          Sidekiq::Testing.inline! do
            post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: time_line_table.id, effective_date: company.time.to_date + 4.days] }, as: :json
          end
        end
        it 'creates a new ctus with state queue' do
          expect(user.custom_table_user_snapshots.last.state).to eq('applied')
        end
      end
    end

    context 'employee accessing mass_create' do
      before do
        user.update_column(:role, 0)
      end
      it 'should deny access' do
        Sidekiq::Testing.inline! do
          response = post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: time_line_table.id, effective_date: company.time.to_date] }, as: :json
          expect(response.status).to eq(403)
        end
      end
    end

    context 'admin accessing mass_create' do
      before do
        user.update_column(:role, 1)
      end
      it 'should access access' do
        Sidekiq::Testing.inline! do
          response = post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: time_line_table.id, effective_date: company.time.to_date] }, as: :json
          expect(response.status).to eq(201)
        end
      end
    end

    context 'account_owner accessing mass_create' do
      it 'should deny access' do
        Sidekiq::Testing.inline! do
          response = post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], user_id: user.id, state: 'queue', custom_table_id: time_line_table.id, effective_date: company.time.to_date] }, as: :json
          expect(response.status).to eq(201)
        end
      end
    end

    context 'custom_table of type approval with effective_date of pasts' do
      it 'creates snapshot with applied state' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], requester_id: user.id, request_state: 2, effective_date: company.time.to_date - 2.days, user_id: user.id, state: 'queue', custom_table_id: approval_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.first.state).to eq("applied")
      end
    end

    context 'custom_table of type approval with effective_date of present' do
      it 'creates snapshot with applied state' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], requester_id: user.id, request_state: 2, effective_date: company.time.to_date, user_id: user.id, state: 'queue', custom_table_id: approval_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.first.state).to eq("applied")
      end
    end

    context 'approval table having exisitng ctus' do

      before do
        user.custom_table_user_snapshots.create(custom_table: approval_table, effective_date: company.time.to_date - 2.days, state: 'applied')
      end

      it 'should create ctus with queued state for ctus having future effective_date' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], requester_id: user.id, request_state: 2, effective_date: company.time.to_date + 4.days, user_id: user.id, state: 'queue', custom_table_id: approval_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.last.state).to eq("queue")
      end

      it 'should create ctus with applied state for ctus having effective_date - 1day' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], requester_id: user.id, request_state: 2, effective_date: company.time.to_date - 1.days, user_id: user.id, state: 'queue', custom_table_id: approval_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.last.state).to eq("applied")
        expect(user.reload.custom_table_user_snapshots.first.state).to eq("processed")
      end

      it 'should create ctus with processed state for ctus having oldest date' do
        Sidekiq::Testing.inline! do
          post :mass_create, params: { snapshots: [custom_snapshots: [{'custom_field_id' => custom_field.id, 'custom_field_value' => 'Abc' }], requester_id: user.id, request_state: 2, effective_date: company.time.to_date - 10.days, user_id: user.id, state: 'queue', custom_table_id: approval_table.id] }, as: :json
        end
        expect(user.reload.custom_table_user_snapshots.last.state).to eq("processed")
      end

    end
  end

  describe 'abilities' do
    context 'when user is a super admin' do
      it { is_expected.to be_able_to(:manage, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }
    end

    context 'when user is an admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end

      it { is_expected.to be_able_to(:create, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }

      it { is_expected.to be_able_to(:update, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }

      it { is_expected.to be_able_to(:destroy, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }
    end

    context 'when user is an employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it { is_expected.to be_able_to(:create, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }

      it { is_expected.to be_able_to(:update, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }

      it { is_expected.to be_able_to(:destroy, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }
    end

    context 'when user is a manager' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      it { is_expected.to be_able_to(:create, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }

      it { is_expected.to be_able_to(:update, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }

      it { is_expected.to be_able_to(:destroy, CustomTableUserSnapshot.new(user: employee, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
          custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])) }
    end
  end

  describe 'POST #create' do
    context 'should not create custom table user snapshots' do
      context 'should not create custom table user snapshot for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(401)
        end
      end

      context "should not create custom table user snapshot of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return forbidden status' do
          allow(controller).to receive(:current_user).and_return(other_user)

          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end
      end
    end

    context 'when user is super admin' do
      context 'should create custom table user snapshot when current user is super admin' do
        it 'should create custom table user snapshot of own' do
          post :create, params: { user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create custom table user snapshot of admin' do
          post :create, params: { user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create custom table user snapshot of employee' do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create custom table user snapshot of manager' do
          post :create, params: { user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it "should return necessary keys count of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end

    context 'when user is admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end
      context 'should create custom table user snapshot when current user is admin' do
        it 'should create custom table user snapshot of own' do
          post :create, params: { user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create custom table user snapshot of super admin' do
          post :create, params: { user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create custom table user snapshot of employee' do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create custom table user snapshot of manager' do
          post :create, params: { user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it "should return necessary keys count of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
            expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end

    context 'when user is manager' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      context 'should not create custom table user snapshot when current user is manager' do
        it 'should not create custom table user snapshot of super admin' do
          post :create, params: { user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not create custom table user snapshot of employee which are not being managed' do
          post :create, params: { user_id: employee_2.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not create custom table user snapshot of admin' do
          post :create, params: { user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context 'should create custom table user snapshot when current user is manager' do
        it 'should create custom table user snapshot of own' do
          post :create, params: { user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create custom table user snapshot of employee which are being managed' do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it "should return necessary keys count of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
            expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end

    context 'when user is employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      context 'should not create custom table user snapshot when current user is employee' do
        it 'should not create custom table user snapshot of super admin' do
          post :create, params: { user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not create custom table user snapshot of manager' do
          post :create, params: { user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not create custom table user snapshot of other employees' do
          post :create, params: { user_id: employee_2.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not create custom table user snapshot of admin' do
          post :create, params: { user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context 'should create custom table user snapshot when current user is employee' do
        it 'should create custom table user snapshot of own' do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(response.status).to eq(201)
        end

        it "should return necessary keys count of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
            expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          post :create, params: { user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue] }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end
  end

  describe 'PUT/PATCH #update' do
    context 'should not update custom table user snapshots' do
      let(:custom_table_user_snapshot) {create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)}

      context 'should not update custom table user snapshot for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(401)
        end
      end

      context "should not update custom table user snapshot of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return forbidden status' do
          allow(controller).to receive(:current_user).and_return(other_user)

          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end
      end
    end

    context 'when user is super admin' do
      context 'should update custom table user snapshot when current user is super admin' do
        it 'should update custom table user snapshot of own' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
        end

        it 'should update custom table user snapshot of admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
       end

        it 'should update custom table user snapshot of employee' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
         end

        it 'should update custom table user snapshot of manager' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
          end

        it "should return necessary keys count of custom table user snapshot" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end

    context 'when user is admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end
      context 'should update custom table user snapshot when current user is admin' do
        it 'should update custom table user snapshot of own' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
         end

        it 'should update custom table user snapshot of super admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
        end

        it 'should update custom table user snapshot of employee' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
        end

        it 'should update custom table user snapshot of manager' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
        end

        it "should return necessary keys count of custom table user snapshot" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end

    context 'when user is manager' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      context 'should not update custom table user snapshot when current user is manager' do
        it 'should not update custom table user snapshot of super admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not update custom table user snapshot of employee which are not being managed' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee_2.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not update custom table user snapshot of admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context 'should update custom table user snapshot when current user is manager' do
        it 'should update custom table user snapshot of own' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
        end

        it 'should update custom table user snapshot of employee which are being managed' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
        end

        it "should return necessary keys count of custom table user snapshot" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end

    context 'when user is employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      context 'should not update custom table user snapshot when current user is employee' do
        it 'should not update custom table user snapshot of super admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not update custom table user snapshot of manager' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not update custom table user snapshot of other employees' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee_2.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not update custom table user snapshot of admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context 'should update custom table user snapshot when current user is employee' do
        before do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :update, params: { id: custom_table_user_snapshot.id, effective_date: Date.today }, as: :json
        end

        it 'should update custom table user snapshot of own' do
          expect(response.status).to eq(201)
          expect(JSON.parse(response.body)['effective_date']).to eq(Date.today.to_s)
        end

        it "should return necessary keys count of custom table user snapshot" do
          expect(JSON.parse(response.body).keys.count).to eq(13)
        end

        it "should return necessary keys of custom table user snapshot" do
          expect(JSON.parse(response.body).keys).to eq(["id", "updated_by", "custom_snapshots", "updated_at", "created_at", "effective_date", "state", "request_state", "is_terminated", "terminated_data", "integration_type", "is_applicable", "is_offboarded"])
        end

        it "should return necessary keys count of custom snapshots" do
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys.count).to eq(10)
        end

        it "should return necessary keys of custom snapshots" do
          expect(JSON.parse(response.body)["custom_snapshots"][0].keys).to eq(["id", "custom_field_id", "preference_field_id", "custom_field_value", "position", "value_text", "coworker", "is_employment_status_field", "hide", "name"])
        end
      end
    end
  end

  describe 'POST #destroy' do
    context 'should not destroy custom table user snapshots' do
      let(:custom_table_user_snapshot) {create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)}

      context 'should not destroy custom table user snapshot for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(401)
        end
      end

      context "should not destroy custom table user snapshot of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return forbidden status' do
          allow(controller).to receive(:current_user).and_return(other_user)

          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end
      end
    end

    context 'when user is super admin' do
      context 'should destroy custom table user snapshot when current user is super admin' do
        it 'should destroy custom table user snapshot of own' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end

        it 'should destroy custom table user snapshot of admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
       end

        it 'should destroy custom table user snapshot of employee' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end

        it 'should destroy custom table user snapshot of manager' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end
      end
    end

    context 'when user is admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end
      context 'should destroy custom table user snapshot when current user is admin' do
        it 'should destroy custom table user snapshot of own' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end

        it 'should destroy custom table user snapshot of super admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end

        it 'should destroy custom table user snapshot of employee' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end

        it 'should destroy custom table user snapshot of manager' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end
      end
    end

    context 'when user is manager' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      context 'should not destroy custom table user snapshot when current user is manager' do
        it 'should not destroy custom table user snapshot of super admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not destroy custom table user snapshot of employee which are not being managed' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee_2.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not destroy custom table user snapshot of admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context 'should destroy custom table user snapshot when current user is manager' do
        it 'should destroy custom table user snapshot of own' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end

        it 'should destroy custom table user snapshot of employee which are being managed' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end
      end
    end

    context 'when user is employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      context 'should not destroy custom table user snapshot when current user is employee' do
        it 'should not destroy custom table user snapshot of super admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: super_admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not destroy custom table user snapshot of manager' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: manager.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not destroy custom table user snapshot of other employees' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee_2.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end

        it 'should not destroy custom table user snapshot of admin' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: admin.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context 'should destroy custom table user snapshot when current user is employee' do
        it 'should destroy custom table user snapshot of own' do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)
          post :destroy, params: { id: custom_table_user_snapshot.id }, as: :json
          expect(response.status).to eq(204)
          expect(CustomTableUserSnapshot.all.count).to eq(0)
        end
      end
    end
  end

  describe 'GET #updates_page_ctus' do
    let (:timeline_approval_custom_table_a) { create(:approval_custom_table, company: company, table_type: CustomTable.table_types[:timeline], name: 'Approval Timeline CustomTable A', is_approval_required: true, approval_expiry_time: 1, approval_chains_attributes: [{ approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1']}]) }

    context 'should not get updates page ctus' do
      let(:custom_table_user_snapshot) {create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_custom_table_a.id, effective_date: 2.days.ago)}

      context 'should not get custom table user snapshot for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          get :updates_page_ctus, as: :json
          expect(response.status).to eq(401)
        end
      end
    end

    context 'should get updates page ctus' do
      context 'employee should get updates page ctus' do
        before do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_approval_custom_table_a.id, effective_date: 2.days.ago)
          allow(controller).to receive(:current_company).and_return(company)
          allow(controller).to receive(:current_user).and_return(employee)
          get :updates_page_ctus, as: :json
        end
        it "should return 200 status" do
          expect(response.status).to eq(200)
        end
      end

      context 'admin should get updates page ctus' do
        before do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_approval_custom_table_a.id, effective_date: 2.days.ago)
          allow(controller).to receive(:current_company).and_return(company)
          allow(controller).to receive(:current_user).and_return(admin)
          get :updates_page_ctus, as: :json
        end
        it "should return 200 status" do
          expect(response.status).to eq(200)
        end
      end

      context 'manager should get updates page ctus' do
        before do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_approval_custom_table_a.id, effective_date: 2.days.ago)
          allow(controller).to receive(:current_company).and_return(company)
          allow(controller).to receive(:current_user).and_return(manager)
          get :updates_page_ctus, as: :json
        end
        it "should return 200 status" do
          expect(response.status).to eq(200)
        end
      end

      context 'super admin should get updates page ctus' do
        before do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_approval_custom_table_a.id, effective_date: 2.days.ago)
          allow(controller).to receive(:current_company).and_return(company)
          allow(controller).to receive(:current_user).and_return(super_admin)
          get :updates_page_ctus, as: :json
        end
        it "should return 200 status" do
          expect(response.status).to eq(200)
        end
      end

      context "should get updates page ctus" do
        before do
          custom_table_user_snapshot = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: timeline_approval_custom_table_a.id, effective_date: 2.days.ago, request_state: CustomTableUserSnapshot.request_states[:requested])
          allow(controller).to receive(:current_company).and_return(company)
          allow(controller).to receive(:current_user).and_return(super_admin)
          get :updates_page_ctus, as: :json
          @result = JSON.parse(response.body)
        end
        it "should return 200 status" do
          expect(response.status).to eq(200)
        end

        it "should return necessary keys count of custom table user snapshots" do
          expect(@result[0].keys.count).to eq(6)
        end

        it "should return necessary keys of custom table user snapshots" do
          expect(@result[0].keys).to eq(["custom_table_name", "requested_by", "requested_date", "user", "expiry_days_left", "current_approver_data"])
        end

        it "should return necessary keys count of user" do
          expect(@result[0]['user'].keys.count).to eq(7)
        end

        it "should return necessary keys name of user" do
          expect(@result[0]['user'].keys).to eq(["id", "picture", "name", "preferred_name", "first_name", "last_name", "display_name"])
        end
      end
    end
  end
end
