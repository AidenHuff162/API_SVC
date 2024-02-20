module Api
  module V1
    module Auth
      class TokenValidationsController < ::DeviseTokenAuth::TokenValidationsController
        include CustomAuthentication

        def validate_token
          # @resource will have been set by set_user_by_token concern
          if current_company&.ids_authentication_feature_flag
            @resource = authenticate_by_ids_token
            render_validate_token_status

          else
            render_validate_token_status
          end
        end

        protected

        def render_validate_token_status
          if @resource
            render_validate_token_success
          else
            render_validate_token_error
          end
        end

        def render_validate_token_success
          render json: @resource, serializer: UserSerializer::Full, include: '**'
        end

        def render_validate_token_error
          render json: { errors: [Errors::Unauthorized.error] }, status: :unauthorized
        end
      end
    end
  end
end
