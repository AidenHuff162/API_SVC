module Api
  module V1
    class InvitesController < ApiController
      include DeviseTokenAuth::Concerns::SetUserByToken
      before_action :require_company!
      before_action :set_invite_by_token
      before_action :authenticate_user!
      before_action :verify_current_user_in_current_company!
      before_action :setup_invitation

      def show
        render json: @resource, serializer: UserSerializer::Full
      end

      private

      def setup_invitation
        # @client_id = SecureRandom.urlsafe_base64(nil, false)
        # @token     = SecureRandom.urlsafe_base64(nil, false)

        # @resource.tokens[@client_id] = {
        #   token: BCrypt::Password.create(@token),
        #   expiry: (Time.now + DeviseTokenAuth.token_lifespan).to_i
        # }

        if @resource.present?
          @token = @resource.create_token
          @resource.save


          sign_in(:user, @resource, store: false, bypass: false)
        end
      end

      def set_invite_by_token
        if signed_in?
          render json: {signed_in: true}, status: 200
        else
          @invite = Invite.find_by!(token: params[:token])
          user = @invite.user || @invite.user_email.user rescue nil
          if user.present? && ['invited', 'preboarding'].include?(user.current_stage) && user.state == 'active'
            @resource = user
          else
            @resource = nil
          end
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [::Errors::InvalidToken.error] }, status: 456
      end
    end
  end
end
