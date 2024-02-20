module Api
  module V1
    module Beta
      class WorkflowsController < ::ApiController
        include ActionController::HttpAuthentication::Token::ControllerMethods
        before_action :require_company!
        before_action :authenticate
        before_action :initialize_api
        skip_before_action :set_current_user_in_model
        
        def index
          workflow_index_route_data = @sapling_api.manage_workflows_index_route_data(params)
          log_response_data(workflow_index_route_data, 'Beta::WorkflowsController/index')
          respond_with workflow_index_route_data
        end

        def show
          workflow_show_route_data = @sapling_api.manage_workflows_show_route_data(params)
          log_response_data(workflow_show_route_data, 'Beta::WorkflowsController/show')
          respond_with workflow_show_route_data
        end

        def tasks
          workflow_show_route_data = @sapling_api.create_workflow_task(params)
          log_response_data(workflow_show_route_data, 'Beta::WorkflowsController/tasks')
          respond_with workflow_show_route_data
        end

        def create
          begin
            ws = Workstream.create!(name: params[:workflow_name],
                                    tasks_count: params[:tasks_count],
                                    company: current_company)
            log_request('200', 'Success', 'Beta::WorkflowsController/create')
            render json: { status: 200, workflow: ws }
          rescue
            log_request('500', 'Request failed', 'Beta::WorkflowsController/create')
            render json: { status: 500, message: 'Request failed' }
          end
        end

        private
        def log_response_data(res, location)
          if res[:status] != '200'
            log_request(res[:status].to_s, res[:message], location)
          else
            log_request('200', 'Success', location)
          end
        end
      end
    end
  end
end
