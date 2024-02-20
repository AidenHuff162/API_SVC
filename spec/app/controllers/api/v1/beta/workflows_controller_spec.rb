require 'rails_helper'

RSpec.describe Api::V1::Beta::WorkflowsController, type: :controller do
  let(:company) { create(:company, subdomain: 'workflows') }
  let(:other_company) { create(:company, subdomain: 'otherworkflows') }
  let(:user) { create(:user, company: company) }
  let(:api_key) { create(:api_key, company: company) }
  let(:workstream) { create(:workstream, company: company) }

  before do
    @key = JsonWebToken.encode({company_id: company.id, Time: Time.now.to_i})
    api_key.key = SCrypt::Password.create(@key)
    api_key.save!
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'GET #index' do
    context 'not get workflows' do
      context 'it should not get workflows if token is not present' do
        it 'should reutrn unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
      context 'it should not get workflows if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
      context 'It should not get workflows of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
      context 'It should not get workflows if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'get workflows' do
      context 'it should get workflows with out applying any limit' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total workflows' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(1)
          expect(@body['total_workflows']).to eq(1)
        end

        it 'It should return workflows array with necessary key counts' do
          expect(@body['workflows'].count).to eq(1)
          expect(@body['workflows'].first.keys.count).to eq(6)
          expect(@body['workflows'].first.keys).to eq(["workflow_id", "workflow_name", "tasks_count", "created_at", "updated_at", "deleted_at"])
        end
      end
      context 'it should get workflows with applying limit' do
        before do
          5.times do
            create(:workstream, company: company)
          end
          5.times do
            create(:workstream_with_tasks_list, company: company)
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { limit: 5 }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total workflows' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(3)
          expect(@body['total_workflows']).to eq(11)
        end

        it 'It should return workflows array with necessary key counts' do
          expect(@body['workflows'].count).to eq(5)
          expect(@body['workflows'].first.keys.count).to eq(6)
          expect(@body['workflows'].first.keys).to eq(["workflow_id", "workflow_name", "tasks_count", "created_at", "updated_at", "deleted_at"])
        end
      end
      context 'it should get workflows with applying limit and page number' do
        before do
          5.times do
            create(:workstream, company: company)
          end
          5.times do
            create(:workstream_with_tasks_list, company: company)
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { limit: 5, page: 3 }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return third page, total page count and total workflows' do
          expect(@body['current_page']).to eq(3)
          expect(@body['total_pages']).to eq(3)
          expect(@body['total_workflows']).to eq(11)
        end

        it 'It should return workflows array with necessary key counts' do
          expect(@body['workflows'].count).to eq(1)
          expect(@body['workflows'].first.keys.count).to eq(6)
          expect(@body['workflows'].first.keys).to eq(["workflow_id", "workflow_name", "tasks_count", "created_at", "updated_at", "deleted_at"])
        end
      end
    end
  end

  describe 'GET #show' do
    context 'not get workflow' do
      context 'it should not get workflow if token is not present' do
        it 'should reutrn unauthorized status' do
          get :show, params: { id: workstream.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not get workflow if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          get :show, params: { id: workstream.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get workflow of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :show, params: { id: workstream.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get workflow if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          get :show, params: { id: workstream.id }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not get workflow if workflow is not present' do
        it 'It should return not found status and log data' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :show, params: { id: 12000 }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Record not found')
          expect(JSON.parse(response.body)['status']).to eq(404)
        end
      end
    end

    context 'get workflow' do
      context 'it should get workflow by providing workstream id' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :show, params: { id: workstream.id }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return workflow with necessary key and count' do
          expect(@body['workflow'].keys.count).to eq(6)
          expect(@body['workflow'].keys).to eq(["workflow_id", "workflow_name", "tasks_count", "created_at", "updated_at", "deleted_at"])
        end
      end
    end
  end

  describe 'post #tasks' do
    before do
      @params = {
        workflow_id: workstream.id,
        name: 'test task',
        description: 'test description',
        owner_guid: user.guid,
        task_type: '0',
        days_due: 2,
        delayed_assignment: 'yes',
        delayed_assigment_days: 1
        }
      request.env["HTTP_ACCEPT"] = 'application/json'
    end
    context 'not create task' do
      context 'it should not create task if token is not present' do
        it 'should reutrn unauthorized status' do
          post :tasks, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not create task if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          post :tasks, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not create task of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          post :tasks, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not create task if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          post :tasks, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not create task if params are invalid' do\
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        end

        it 'It should return bad request error if workflow id is not present' do
          @params[:workflow_id] = nil
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'It should return bad request error if workflow id is invalid number' do
          @params[:workflow_id] = 123123
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'It should return bad request error if workflow id is alphabets' do
          @params[:workflow_id] = "abc"
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'It should return bad request error if name is not present' do
          @params[:name] = nil
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'It should return bad request error if owner guid is not present' do
          @params[:owner_guid] = nil
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'It should return bad request error if owner guid is invalid number' do
          @params[:owner_guid] = 234
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'It should return bad request error if owner guid is alphabets' do
          @params[:owner_guid] = "abc"
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end

        it 'It should return bad request error if task type is invalid enum' do
          @params[:task_type] = 1000
          post :tasks, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Augment Error::Unprocessable Parameters')
          expect(JSON.parse(response.body)['status']).to eq(nil)
        end
      end
    end
    context 'create task' do
      before do
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        post :tasks, params: @params, format: :json
        @body = JSON.parse(response.body)
      end


      it 'It should return success status and log data' do
        expect(response).to have_http_status(:success)
        expect(ApiLogging.count).to eq(1)
      end

      it 'It should return task with necessary key counts' do
        expect(@body['task'].count).to eq(1)
        expect(@body['task'][0].keys.count).to eq(20)
        expect(@body['task'][0].keys).to eq(["id", "workstream_id", "name", "description", "created_at", "updated_at", "owner_id", "deadline_in", "position", "task_type", "deleted_at", "time_line", "before_deadline_in", "workspace_id", "sanitized_name", "custom_field_id", "task_schedule_options", "survey_id", "dependent_tasks", 'env_migration'])
      end
    end
  end

  describe 'post #create' do
    before do
      @params = {
        workflow_name: "test workflow",
        tasks_count: "2",
        }
      request.env["HTTP_ACCEPT"] = 'application/json'
    end
    context 'not create workflow' do
      context 'it should not create workflow if token is not present' do
        it 'should reutrn unauthorized status' do
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not create workflow if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not create workflow of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not create workflow if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not create workflow if params are invalid' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        end

        it 'It should return bad request error if name is not present' do
          @params[:workflow_name] = nil
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Request failed')
          expect(JSON.parse(response.body)['status']).to eq(500)
        end
      end
    end

    context 'create workflow' do
      before do
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        post :create, params: @params, format: :json
        @body = JSON.parse(response.body)
      end


      it 'It should return success status and log data' do
        expect(response).to have_http_status(:success)
        expect(ApiLogging.count).to eq(1)
      end

      it 'It should return workflow with necessary key counts' do
        expect(@body['workflow'].keys.count).to eq(12)
        expect(@body['workflow'].keys).to eq(["id", "company_id", "name", "created_at", "updated_at", "tasks_count", "position", "deleted_at", "meta", "updated_by_id", "process_type_id", "sort_type"])
      end
    end
  end
end
