module Api
  module V1
    module Beta
      class GroupfieldsController < BaseController

        def group_fields
          group_fields_route_data = @sapling_api.manage_group_fields_route_data(params)
          log_request('200', 'Success', 'Beta::GroupfieldsController/group_fields')
          render json: group_fields_route_data.as_json
        end
      end
    end
  end
end
