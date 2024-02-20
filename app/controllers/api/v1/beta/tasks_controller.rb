module Api
  module V1
    module Beta
      class TasksController < BaseController
        before_action :validate_update_request, only: [:update]

        def index
          profile_index_route_data = @sapling_api.manage_tasks_index_route_data(params)
          if profile_index_route_data[:status] != 200
            log_request(profile_index_route_data[:status], profile_index_route_data[:message], 'Beta::TasksController/index')
          else
            log_request('200', 'Success', 'Beta::TasksController/index')
          end
          respond_with profile_index_route_data
        end

        def update
          begin
            TaskUserConnection.find(params[:id]).update!(params.permit(:owner_id, :due_date, :state, :completed_by_method))
            log_request('200', 'Success', 'Beta::TasksController/update')
            render json: {status: '200',
                          data: [TaskUserConnection.find(params[:id]).as_json]}
          rescue ActiveRecord::RecordNotFound => e
            log_request('404', 'Record not found', 'Beta::TasksController/update')
            render json: { message: 'Record not found', status: 404 }
          rescue ArgumentError => e
            log_request('422', 'Invalid attributes', 'Beta::TasksController/update')
            render json: { status: '422', message: 'Invalid attributes, please make sure the state and due_date values are valid.' }
          rescue => e
            log_request('500', e.message, 'Beta::TasksController/update')
            render json: { status: 500, message: e.message }
          end
        end

        def destroy
          begin
            TaskUserConnection.find(params[:id]).destroy
            log_request('200', 'Success', 'Beta::TasksController/destroy')
            render json: { status: '200', message: 'Successfully deleted' }
          rescue ActiveRecord::RecordNotFound => e
            log_request('404', 'Record not found', 'Beta::TasksController/destroy')
            render json: { message: 'Record not found', status: 404 }
          rescue => e
            log_request('500', 'Request failed', 'Beta::TasksController/destroy')
            render json: { message: 'Request failed', status: 500 }
          end
        end

        private
        def validate_update_request
          if params[:owner_id] && !User.find_by(id: params[:owner_id])
            log_request('404', 'Owner not found', 'Beta::TasksController/validate_update_request')
            return render(json:{ status: 404, message: 'No user exists for this owner_id'})
          elsif params[:owner_id]
            params[:owner_id] = User.find(params[:owner_id]).id
          end
          if params[:due_date] && params[:due_date] == ''
            log_request('422', 'Invalid due date', 'Beta::TasksController/validate_update_request')
            return render(json:{ status: 422, message: 'Invalid due date'})
          elsif params[:due_date]
            params[:due_date] = params[:due_date].to_date
            if params[:due_date] > (Date.today+40.years) || params[:due_date].nil?
              log_request('422', 'Invalid due date', 'Beta::TasksController/validate_update_request')
              return render(json:{ status: 422, message: 'Invalid due date'})
            end
          end
        end
      end
    end
  end
end
