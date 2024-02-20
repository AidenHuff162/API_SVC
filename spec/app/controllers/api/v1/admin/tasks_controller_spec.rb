require 'rails_helper'

RSpec.describe Api::V1::Admin::TasksController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, role: 2 ) }
  let(:workstream) { create(:workstream, company: user.company) }
  let(:task)  {create(:task, workstream: workstream)}
  let(:task1) {create(:task, workstream: workstream)}
  let(:task2) {create(:task, workstream: workstream)}

  let(:company2) { create(:company, subdomain: 'bar') }
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2, role: 2 )}
  let(:workstream2) { create(:workstream, company:company2) }
  let(:task3) {create(:task, workstream: workstream2)}

  let(:task_user_connection)  {create(:task_user_connection, user: user, task: task)}
  let(:task_user_connection1) {create(:task_user_connection, user: user, task: task1)}
  let(:task_user_connection2) {create(:task_user_connection, user: user, task: task2)}

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
    task.reload
    task3.reload
  end

  describe 'authorization' do
    context 'Authorize User of company' do
      it 'can manage tasks of its company' do
        ability = Ability.new(user)
        expect(ability.can?(:manage, task)).to eq(true)
      end
    end

    context 'user of different company' do
      it 'cannot manage tasks of other company' do
        ability = Ability.new(user2)
        expect(ability.cannot?(:manage, task)).to eq(true)
      end
    end
  end

  describe "DELETE #destroy" do
    context 'UnAuthenticated User' do
      it 'should not allow UnAuthenticated user to destroy a task' do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: task.id  }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'Authenticated User' do
      it 'should destroy a task' do
        delete :destroy, params: { id: task.id  }, format: :json
        expect(Task.find_by(id: task.id)).to eq(nil)
      end

      it "after deleting a task, it's task user connections should not be deleted" do
        task_user_connection = create(:task_user_connection, user: user, task: task)
        delete :destroy, params: { id: task.id  }, format: :json
        expect(user.task_user_connections[0].task_id).to eq(task.id)
        expect(user.task_user_connections.with_deleted.count).to eq(1)
      end
    end

    context 'user and current user belonging to different company' do
      it 'should not delete task of other company' do
        allow(controller).to receive(:current_user).and_return(user2)
        delete :destroy, params: { id: task.id  }, format: :json
        expect(response.status).to eq(403)
      end

      it 'should not have ability to delete task' do
        allow(controller).to receive(:current_user).and_return(user2)
        ability = Ability.new(user2)
        assert ability.cannot?(:destroy, task)
      end
    end
  end

  describe "Create and Save Task #create" do
    context 'UnAuthenticated User' do
      it 'should not allow to create a task' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { workstream_id: workstream.id, name: "hello", deadline_in: 7, time_line: 'immediately', task_type: 'hire' }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'Authenticated User' do
      it "should create a task and save it" do
        post :create, params: { workstream_id: workstream.id, name: "hello", deadline_in: 7, time_line: 'immediately', task_type: 'hire' }, format: :json
        expect(response.message).to eq('Created')
      end
    end

    context 'user belonging to different company' do
      it "should not create a task in other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        post :create, params: { workstream_id: workstream.id, name: "hello", deadline_in: 7, time_line: 'immediately', task_type: 'hire' }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "Update Task #update" do
    context 'UnAuthenticated User' do
      it 'should not allow to update a task' do
        allow(controller).to receive(:current_user).and_return(nil)
        put :update, params: { id: task.id, workstream_id: task.workstream_id, name: "new_name", deadline_in: 7, time_line: 'immediately', task_type: 'hire' }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'Authenticated User' do
      it "should update a task" do
        put :update, params: { id: task.id, workstream_id: task.workstream_id, name: "new_name", deadline_in: 7, time_line: 'immediately', task_type: 'hire' }, format: :json
        expect(JSON.parse(response.body)['name']).to eq('new_name')
      end

      it "should not change tasks in workstream of other company" do
        put :update, params: { id: task3.id, workstream_id: task3.workstream_id, name: "new_name", deadline_in: 7, time_line: 'immediately', task_type: 'hire' }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'user belonging to different company' do
      it "should not update a task" do
        allow(controller).to receive(:current_user).and_return(user2)
        put :update, params: { id: task.id, workstream_id: task.workstream_id, name: "new_name", deadline_in: 7, time_line: 'immediately', task_type: 'hire' }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "Show a Task #show" do
    context 'UnAuthenticated User' do
      it 'should not show task to UnAuthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :show, params: { id: task.id }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'Authenticated User' do
      it "should show a task" do
        get :show, params: { id: task.id }, format: :json
        expect(JSON.parse(response.body)["id"]).to eq(task.id)
      end
    end

    context 'user belonging to different company' do
      it "should not show task" do
        allow(controller).to receive(:current_user).and_return(user2)
        get :show, params: { id: task.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "GET #index" do
    context 'UnAuthenticated User' do
      it 'should not get tasks' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, params: { workstream_id: workstream.id  }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'Authenticated User' do
      it "should get all tasks" do
        get :index, params: { workstream_id: workstream.id  }, format: :json
        expect(JSON.parse(response.body).length).to eq(1)
      end

      it "should not get all tasks from workstream of other company" do
        get :index, params: { workstream_id: workstream2.id  }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'user belonging to different company' do
      it "should not get all tasks" do
        allow(controller).to receive(:current_user).and_return(user2)
        get :index, params: { workstream_id: workstream.id  }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "Update Workstream #update_workstream" do
    context 'UnAuthenticated User' do
      it 'should not update workstream of a task' do
        allow(controller).to receive(:current_user).and_return(nil)
        put :update_workstream, params: { id: task.id, source_workstream_id: workstream.id, workstream_id: workstream2.id }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'Authenticated User' do
      it "should update workstream of a task" do
        put :update_workstream, params: { id: task.id, source_workstream_id: workstream.id, workstream_id: workstream2.id }, format: :json
        expect(JSON.parse(response.body)["workstream_id"]).to eq(workstream2.id)
      end
    end

    context 'user belonging to different company' do
      it "should not show task" do
        allow(controller).to receive(:current_user).and_return(user2)
        put :update_workstream, params: { id: task.id, source_workstream_id: workstream.id, workstream_id: workstream2.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#paginated" do
    before do
      task1.reload
      task2.reload
      task_user_connection.reload
      task_user_connection1.reload
      task_user_connection2.reload
    end

    context 'UnAuthenticated User' do
      it 'should not call #paginated' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :paginated, params: { company_id: company.id, open: true, page: "1", per_page: "2", tuc_counts: "true", users_params: "{\"term\":null,\"start\":0,\"length\":10,\"sort_column\":\"start_date\",\"sort_order\":\"desc\",\"dashboard_search\":true,\"sub_tab\":\"dashboard\"}" }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'user belonging to different company' do
      it "should not call #paginated" do
        allow(controller).to receive(:current_user).and_return(user2)
        get :paginated, params: { company_id: company.id, open: true, page: "1", per_page: "2", tuc_counts: "true", users_params: "{\"term\":null,\"start\":0,\"length\":10,\"sort_column\":\"start_date\",\"sort_order\":\"desc\",\"dashboard_search\":true,\"sub_tab\":\"dashboard\"}" }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end
end
