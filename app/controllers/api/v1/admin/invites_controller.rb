module Api
  module V1
    module Admin
      class InvitesController < BaseController
        load_and_authorize_resource :user
        load_and_authorize_resource :invite, through: :user, shallow: true
        
        def resend_invitation_email
          message = Invite.resend_invitation_email(params[:user_id], current_company)
          respond_with message.to_json
        end

        private

        def invite_params
          params.permit(:subject, :cc, :bcc, :description, :invite_at)
        end

        def authorize_attachments
          UploadedFile::Attachment.where(id: attachment_ids).find_each do |attachment|
            authorize! :manage, attachment
          end
        end
      end
    end
  end
end
