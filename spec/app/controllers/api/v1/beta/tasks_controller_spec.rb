require 'rails_helper'

RSpec.describe Api::V1::Beta::TasksController, type: :controller do
  let(:company) { create(:company, subdomain: 'tasks') }
  let(:other_company) { create(:company, subdomain: 'othertasks') }
  let(:user) { create(:user, company: company) }
  let(:api_key) { create(:api_key, company: company) }
  let(:workstream) { create(:workstream, company: company) }
  let(:task) { create(:task, workstream: workstream) }
  let(:tuc) { create(:task_user_connection, task: task, user: build(:user)) }

  before do
    @key = JsonWebToken.encode({company_id: company.id, Time: Time.now.to_i})
    api_key.key = SCrypt::Password.create(@key)
    api_key.save!
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'GET #index' do
    context 'not get tasks' do
      context 'it should not get tasks if token is not present' do
        it 'should reutrn unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not get tasks if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get tasks of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get tasks if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get tasks if owner does not exist ' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { owner_email: 'abc@gamil.com' }, format: :json
          expect(JSON.parse(response.body)['status']).to eq(404)
          expect(JSON.parse(response.body)['message']).to eq('No owner found with this email')
        end
      end
    end

    context 'get tasks' do
      context 'it should get tasks with out applying any limit' do
        before do
          create(:task_user_connection, task: task, user: user)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total tasks' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(1)
          expect(@body['total_tasks']).to eq(1)
        end

        it 'It should return tasks array with necessary key counts' do
          expect(@body['tasks'].count).to eq(1)
          expect(@body['tasks'].first.keys.count).to eq(16)
          expect(@body['tasks'].first.keys).to eq(["workflow_id", "workflow_name", "task_id", "name", "workspace_name", "description", "created_at", "updated_at", "owner_guid", "owner_email", "owner_name", "receiver_guid", "receiver_email", "receiver_name", "due_date", "state"])
        end
      end

      context 'it should get tasks with applying limit' do
        before do
          6.times do
            create(:task_user_connection, task: task, user: build(:user))
          end
          5.times do
            create(:scheduled_task_user_connection, task: task, user: build(:user))
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { limit: 5 }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total tasks' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(3)
          expect(@body['total_tasks']).to eq(11)
        end

        it 'It should return tasks array with necessary key counts' do
          expect(@body['tasks'].count).to eq(5)
          expect(@body['tasks'].first.keys.count).to eq(16)
          expect(@body['tasks'].first.keys).to eq(["workflow_id", "workflow_name", "task_id", "name", "workspace_name", "description", "created_at", "updated_at", "owner_guid", "owner_email", "owner_name", "receiver_guid", "receiver_email", "receiver_name", "due_date", "state"])
        end
      end

      context 'it should get tasks by applying limit and page number' do
        before do
          6.times do
            create(:task_user_connection, task: task, user: build(:user))
          end
          5.times do
            stuc = create(:scheduled_task_user_connection, task: task, user: build(:user))
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { limit: 5, page: 3 }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return third page, total page count and total tasks' do
          expect(@body['current_page']).to eq(3)
          expect(@body['total_pages']).to eq(3)
          expect(@body['total_tasks']).to eq(11)
        end

        it 'It should return tasks array with necessary key counts' do
          expect(@body['tasks'].count).to eq(1)
          expect(@body['tasks'].first.keys.count).to eq(16)
          expect(@body['tasks'].first.keys).to eq(["workflow_id", "workflow_name", "task_id", "name", "workspace_name", "description", "created_at", "updated_at", "owner_guid", "owner_email", "owner_name", "receiver_guid", "receiver_email", "receiver_name", "due_date", "state"])
        end
      end

      context 'it should get tasks by applying state filter' do
        before do
          6.times do
            create(:task_user_connection, task: task, user: build(:user))
          end
          5.times do
            stuc = create(:scheduled_task_user_connection, task: task, user: build(:user))
            stuc.complete
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { state: 'completed' }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return current page, total page count and total tasks' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(1)
          expect(@body['total_tasks']).to eq(5)
        end

        it 'It should return tasks array with necessary key counts' do
          expect(@body['tasks'].count).to eq(5)
          expect(@body['tasks'].first.keys.count).to eq(16)
          expect(@body['tasks'].first.keys).to eq(["workflow_id", "workflow_name", "task_id", "name", "workspace_name", "description", "created_at", "updated_at", "owner_guid", "owner_email", "owner_name", "receiver_guid", "receiver_email", "receiver_name", "due_date", "state"])
        end
      end

      context 'it should get tasks by applying overdue filter only' do
        before do
          2.times do
            create(:scheduled_task_user_connection, task: task, user: build(:user))
          end
          2.times do
            create(:overdue_task_user_connection, task: task, user: build(:user))
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { overdue: true }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return current page, total page count and total tasks' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(1)
          expect(@body['total_tasks']).to eq(2)
        end

        it 'It should return tasks array with necessary key counts' do
          expect(@body['tasks'].count).to eq(2)
          expect(@body['tasks'].first.keys.count).to eq(16)
          expect(@body['tasks'].first.keys).to eq(["workflow_id", "workflow_name", "task_id", "name", "workspace_name", "description", "created_at", "updated_at", "owner_guid", "owner_email", "owner_name", "receiver_guid", "receiver_email", "receiver_name", "due_date", "state"])
        end
      end

      context 'it should get tasks by applying upcoming filter only' do
        before do
          2.times do
            create(:scheduled_task_user_connection, task: task, user: build(:user))
          end
          2.times do
            create(:overdue_task_user_connection, task: task, user: build(:user))
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { upcoming: true }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return current page, total page count and total tasks' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(1)
          expect(@body['total_tasks']).to eq(2)
        end

        it 'It should return tasks array with necessary key counts' do
          expect(@body['tasks'].count).to eq(2)
          expect(@body['tasks'].first.keys.count).to eq(16)
          expect(@body['tasks'].first.keys).to eq(["workflow_id", "workflow_name", "task_id", "name", "workspace_name", "description", "created_at", "updated_at", "owner_guid", "owner_email", "owner_name", "receiver_guid", "receiver_email", "receiver_name", "due_date", "state"])
        end
      end
    end
  end

  describe 'put #update' do
    before do
      @params = {
        id: tuc.id,
        due_date: 2.days.from_now,
        state: 'completed',
        completed_by_method: :email
        }
      request.env["HTTP_ACCEPT"] = 'application/json'
    end
    context 'not update task' do
      context 'it should not update task if token is not present' do
        it 'should reutrn unauthorized status' do
          put :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not update task if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          put :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not update task of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          put :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not update task if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          put :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not update task if params are invalid' do\
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        end

        it 'should return not found error if owner id is invalid' do
          put :update, params: { id: tuc.id, owner_id: 4500 }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('No user exists for this owner_id')
          expect(JSON.parse(response.body)['status']).to eq(404)
        end

        it 'should return Invalid due date error if due data is empty' do
          put :update, params: { id: tuc.id, due_date: '' }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Invalid due date')
          expect(JSON.parse(response.body)['status']).to eq(422)
        end

        it 'should return Invalid due date error if due data is more than 40 years' do
          put :update, params: { id: tuc.id, due_date: 42.years.from_now }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Invalid due date')
          expect(JSON.parse(response.body)['status']).to eq(422)
        end

        it 'should return state error if state is inavlid' do
          put :update, params: { id: tuc.id, state: 'abc' }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Validation failed: State is invalid')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'should return state error if completed by method is inavlid' do
          put :update, params: { id: tuc.id, completed_by_method: 'abc' }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Invalid attributes, please make sure the state and due_date values are valid.')
          expect(JSON.parse(response.body)['status']).to eq('422')
        end
      end
    end

    context 'update task' do
      before do
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        put :update, params: @params, format: :json
        @body = JSON.parse(response.body)
      end

      it 'It should return success status and log data' do
        expect(response).to have_http_status(:success)
        expect(ApiLogging.count).to eq(1)
      end

      it 'It should return task with necessary key counts' do
        expect(@body["data"][0].keys.count).to eq(30)
        expect(@body["data"][0].keys).to eq(["id", "user_id", "task_id", "state", "created_at", "updated_at", "owner_id", "due_date", "activity_seen", "is_custom_due_date", "token", "deleted_at", "jira_issue_id", "from_due_date", "before_due_date", "schedule_days_gap", "workspace_id", "owner_type", "is_offboarding_task", "completed_at", "asana_id", "send_to_asana", "completed_by_method", "completion_date", "asana_webhook_gid", "dependent_tuc", "completed_dependent_task_count", 'job_id', 'service_now_id', 'env_migration'])
      end
    end
  end

  describe 'delete #destroy' do
    context 'not delete task' do
      context 'it should not delete task if token is not present' do
        it 'should reutrn unauthorized status' do
          delete :destroy, params: { id: tuc.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not delete task if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          delete :destroy, params: { id: tuc.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not delete task of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          delete :destroy, params: { id: tuc.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not delete task if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          delete :destroy, params: { id: tuc.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not delete task if params are invalid' do\
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        end

        it 'It should return bad request error if task id is invalid' do
          delete :destroy, params: { id: 124 }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Record not found')
          expect(JSON.parse(response.body)['status']).to eq(404)
        end
      end
    end

    context 'delete task' do
      before do
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        delete :destroy, params: { id: tuc.id }, format: :json
        @body = JSON.parse(response.body)
      end

      it 'It should return success status and log data' do
        expect(ApiLogging.count).to eq(1)
        expect(JSON.parse(response.body)['message']).to eq('Successfully deleted')
        expect(JSON.parse(response.body)['status']).to eq('200')
      end
    end
  end
end
