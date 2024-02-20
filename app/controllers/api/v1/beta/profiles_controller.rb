module Api
  module V1
    module Beta
      class ProfilesController < ::ApiController
        include ActionController::HttpAuthentication::Token::ControllerMethods
        before_action :require_company!
        before_action :authenticate, except: [:get_sapling_profile]
        before_action :authenticate_ids_server_request, only: [:get_sapling_profile]
        before_action :initialize_api
        before_action :downcase_param_keys
        skip_before_action :set_current_user_in_model

        def fields
          profile_fields_route_data = @sapling_api.manage_profile_fields_route_data(params)
          log_request('200', 'Success', 'Beta::ProfilesController/fields')
          render json: profile_fields_route_data.as_json
        end

        def index
          profile_index_route_data = @sapling_api.manage_profile_index_route_data(params)
          log_request('200', 'Success', 'Beta::ProfilesController/index')
          respond_with profile_index_route_data
        end

        def show
          show_route_data = @sapling_api.manage_profile_show_route_data(params.to_h)
          log_request('200', 'Success', 'Beta::ProfilesController/show')
          respond_with show_route_data
        end

        def create
          respond_with @sapling_api.manage_profile_create_route_data(params)
        end

        def update
          respond_with @sapling_api.manage_profile_update_route_data(params)
        end

        def get_sapling_profile
          user_profile = @sapling_api.manage_get_sapling_profile_route_data(params)
          log_request('200', 'Success', 'Beta::ProfilesController/get_sapling_user')
          render json: user_profile.as_json
        end

        private

        def downcase_param_keys
          params.transform_keys!(&:downcase)
        end
      end
    end
  end
end
