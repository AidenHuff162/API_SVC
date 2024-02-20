module Api
  module V1
    module Admin
      module EmailPreview
        class UserMailerController < BaseController
          load_and_authorize_resource :user, parent: false

          def invite
            new_invite = invite_params
            new_invite[:description] =  URI.unescape(new_invite[:description])
            @invite = Invite.new(new_invite)
            @description = @invite.description
            @company = @user.company
            @company.owner = @company.owner
            @isPreview = true
            render 'user_mailer/onboarding_email'
          end

          private

          def invite_params
            params.permit(:subject, :cc, :bcc, :description)
          end
        end
      end
    end
  end
end
