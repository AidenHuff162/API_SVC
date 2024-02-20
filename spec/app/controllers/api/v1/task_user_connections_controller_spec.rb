require 'rails_helper'

RSpec.describe Api::V1::TaskUserConnectionsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }
  let(:workstream) { create(:workstream, company: user.company) }
  let(:immediate_task) { create(:task, workstream: workstream) }
  let(:immediate_task_user_connection) { create(:task_user_connection, user: user, task: immediate_task) }
  let(:deleted_task) { create(:task_user_connection, user: user, task: immediate_task) }
  let(:scheduled_task) { create(:scheduled_task, workstream: workstream) }
  let(:scheduled_task_user_connection) { create(:scheduled_task_user_connection, user: user, task: scheduled_task) }
  let(:valid_session) { {} }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
    deleted_task.destroy!
  end

  describe "PUT #update" do
    it "should update the due date change of immediate task" do
      put :update, params: { id: immediate_task_user_connection.id, due_date: (Date.today + 10) }, format: :json
      from_due_date = immediate_task_user_connection.from_due_date
      immediate_task_user_connection.reload
      expect(immediate_task_user_connection.due_date).to eq(Date.today + 10)
      expect(immediate_task_user_connection.from_due_date).to eq(from_due_date)
      expect(immediate_task_user_connection.before_due_date).to eq(nil)
    end

    it "should update the due date and before due date of scheduled task" do
      put :update, params: { id: scheduled_task_user_connection.id, due_date: (Date.today + 17) }, format: :json
      from_due_date = scheduled_task_user_connection.from_due_date
      scheduled_task_user_connection.reload
      expect(scheduled_task_user_connection.due_date).to eq(Date.today + 17)
      expect(scheduled_task_user_connection.from_due_date).to eq(from_due_date)
      expect(scheduled_task_user_connection.before_due_date).to eq(Date.today + 17 + scheduled_task_user_connection.schedule_days_gap)
    end
  end

  describe "GET #update_inactive_task" do
    it "should update the inactive task" do
      put :update_inactive_tasks, params: { id: deleted_task.id, state: "in_progress" }, format: :json
      deleted_task.reload
      user.reload
      expect(deleted_task.state).to eq("in_progress")
      expect(user.task_user_connections.count).to be >= user.task_user_connections.count - user.outstanding_tasks_count
      expect(user.outstanding_tasks_count).to be >= 0
    end
  end

  describe "Admin's access" do
    before do
      user.update(user_role_id: company.user_roles.where(role_type: UserRole.role_types['admin']).take.id)
    end
    context 'Admin with no access' do
      before do
        user.user_role.permissions["own_platform_visibility"]["task"] = "no_access"
        user.save!
      end

      it 'should get 204 on calling #paginated' do
        get :paginated, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should get 204 on calling #index' do
        get :index, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should get 204 on calling #get_tasks_count' do
        get :get_tasks_count, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should get 204 on calling #assign' do
        post :assign, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin with access' do

      it 'should get 200 on calling #paginated' do
        get :paginated, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(200)
      end

      it 'should get 200 on calling #index' do
        get :index, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(200)
      end

      it 'should get 200 on calling #get_tasks_count' do
        get :get_tasks_count, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(200)
      end
    end
  end
end
