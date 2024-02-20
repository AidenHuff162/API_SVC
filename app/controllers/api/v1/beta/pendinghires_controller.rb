module Api
  module V1
    module Beta
      class PendinghiresController < BaseController

        def index
          data = @sapling_api.manage_pending_hire_index_route_data(params)
          respond_with data, status: data[:status]
        end

        def show
          data = @sapling_api.manage_pending_hire_show_route_data(params)
          respond_with data, status: data[:status]
        end

        def create
          data = @sapling_api.manage_pending_hire_create_route_data(params)
          respond_with data, status: data[:status]
        end

        def update
          data = @sapling_api.manage_pending_hire_update_route_data(params)
          respond_with data, status: data[:status]
        end
      end
    end
  end
end