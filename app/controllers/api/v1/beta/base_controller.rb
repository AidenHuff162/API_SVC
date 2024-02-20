module Api
  module V1
    module Beta
      class BaseController < ::ApiController
        include ActionController::HttpAuthentication::Token::ControllerMethods
        before_action :require_company!
        before_action :authenticate
        before_action :initialize_api
        skip_before_action :set_current_user_in_model
      end
    end
  end
end
