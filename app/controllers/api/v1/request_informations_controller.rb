module Api
  module V1
    class RequestInformationsController < ApiController
      include DeviseTokenAuth::Concerns::SetUserByToken

      before_action :require_company!
      before_action :setup_invitation, only: [:show_request_information_form]
      before_action :authenticate_user!
      before_action :verify_current_user_in_current_company!

      load_and_authorize_resource except: [:show_request_information_form]

      def show
        respond_with @request_information, serializer: RequestInformationSerializer::RequestedInformationPage
      end

      def update
        @request_information.update!(request_information_params)
        current_user.update(request_information_form_token: nil) if current_user.request_information_form_token.present? 
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      def show_request_information_form
      end

      private

      def request_information_params
        params.permit(:state)
      end

      def setup_invitation
        @resource = current_company.users.find_by(request_information_form_token: params[:token])
        if @resource.nil?
          render json: { error:'Unauthorized Access' }, status: 200
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
