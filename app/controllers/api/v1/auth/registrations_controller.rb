module Api
  module V1
    module Auth
      class RegistrationsController < ::DeviseTokenAuth::RegistrationsController
        include DeviseTokenAuth::Concerns::SetUserByToken

        prepend_before_action :configure_permitted_parameters

        protected
        def profile_image_params
          params.require(:profile_image).permit(:id)
        end

        def render_create_error
          render json: { errors: [Errors::NotFound.new(@errors[0]).error] }, status: :not_found
        end

        def render_update_error
          render json: { errors: [Errors::UnprocessableEntity.new(@resource).error] }, status: :unprocessable_entity
        end

        def configure_permitted_parameters
          devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :personal_email, :phone_number, :preferred_name])
        end
      end
    end
  end
end
