module Api
  module V1
    class ManagerFormsController < ApiController
      include DeviseTokenAuth::Concerns::SetUserByToken
      before_action :require_company!
      before_action :setup_invitation
      before_action :authenticate_user!
      before_action :verify_current_user_in_current_company!

      def show
      end

      def show_manager_form
        render json: current_user, status: 200
      end

      private

      def setup_invitation
        @resource = current_company.users.find_by(manager_form_token: params[:token])
         if @resource.nil?
          render json: { error:'Unauthorized Access' }, status: 401
        else
          # @client_id = SecureRandom.urlsafe_base64(nil, false)
          # @token     = SecureRandom.urlsafe_base64(nil, false)
          # @resource.tokens[@client_id] = {
          #   token: BCrypt::Password.create(@token),
          #   expiry: (Time.now + DeviseTokenAuth.token_lifespan).to_i
          # }
          @token = @resource.create_token
          @resource.save
          sign_in(:user, @resource, store: false, bypass: false)
        end
      end


    end
  end
end
