module Api
  module V1
    class BaseController < ApiController
      before_action :require_company!
      before_action :authenticate_user!
      before_action :verify_current_user_in_current_company!
    end
  end
end
