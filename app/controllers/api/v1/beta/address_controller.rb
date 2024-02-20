module Api
  module V1
    module Beta
      class AddressController < BaseController

        def countries
          data = @sapling_api.manage_countries_data(params)
          respond_with data, status: data[:status]
        end

        def states
          data = @sapling_api.manage_states_data(params)
          respond_with data, status: data[:status]
        end
      end
    end
  end
end