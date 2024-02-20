module Api
  module V1
    class ProfilesController < ApiController

      include CustomSectionApprovalHandler
      include WebhookHandler

      before_action :require_company!
      before_action :authenticate_user!

      load_and_authorize_resource :user
      load_and_authorize_resource :profile, through: :user, singleton: true

      def create_requested_fields_for_profile_cs_approval
        fields = prepare_fields_for_cs_approval(params.to_h, params[:user_id].to_i, true, 'user_profile')
        return unless fields.present?
        render json: { status: 200 ,fields: fields}
      end

      def update
        tempUser = current_company.users.find_by(id: profile_params[:user_id])
        if tempUser
          tempProfile = tempUser.profile 
        end

        if params[:approval_profile_page]
          params[:facebook] = tempProfile.facebook unless params[:facebook].present?
          params[:twitter] = tempProfile.twitter unless params[:twitter].present?
          params[:about_you] = tempProfile.about_you unless params[:about_you].present?
          params[:linkedin] = tempProfile.linkedin unless params[:linkedin].present?
          params[:github] = tempProfile.github unless params[:github].present?
        end

        if tempUser.present? && tempUser.state == "active" && (tempProfile.about_you != profile_params[:about_you] ||
           tempProfile.facebook != profile_params[:facebook] ||
           tempProfile.twitter != profile_params[:twitter] ||
           tempProfile.linkedin != profile_params[:linkedin] ||
           tempProfile.github != profile_params[:github] )
          PushEventJob.perform_later('profile-updated', current_user, {
            employee_id: tempUser.id,
            employee_name: tempUser.first_name + ' ' + tempUser.last_name,
            employee_email: tempUser.email,
            about_employee: profile_params[:about_you]
          })
        end
        field_name = [] 
        if tempUser.present? && tempUser.state == "active" 
          if tempProfile.about_you != profile_params[:about_you]
            field_name << "About You"
          end
          if  tempProfile.facebook != profile_params[:facebook]
            field_name << "FaceBook"
          end
          if tempProfile.twitter != profile_params[:twitter] 
            field_name << "Twitter"
          end
          if  tempProfile.linkedin != profile_params[:linkedin]
            field_name << "Linkedin"
          end
          if tempProfile.github != profile_params[:github]
            field_name << "Github"
          end
        end
        begin
          history_description = nil
          slack_description = nil

          field_name.try(:each) do |field|

            if tempUser.present? && tempUser.id == current_user.id 
              history_description = I18n.t("history_notifications.profile.own_updated", first_name: tempUser.first_name, last_name: tempUser.last_name,field_name: field)
              slack_description = I18n.t("slack_notifications.profile.own_updated", first_name: tempUser.first_name, last_name: tempUser.last_name)
            elsif tempUser.present?
              history_description = I18n.t("history_notifications.profile.others_updated", full_name: current_user.full_name,field_name: field, first_name: tempUser.first_name, last_name: tempUser.last_name)
              slack_description = I18n.t("slack_notifications.profile.others_updated", full_name: current_user.full_name, first_name: tempUser.first_name, last_name: tempUser.last_name)
            end
            SlackNotificationJob.perform_later(current_company.id, {
              username: current_user.full_name,
              text: slack_description
            }) if slack_description.present?
            History.create_history({
              company: current_company,
              user_id: current_user.id,
              description: history_description,
              attached_users: [current_user.id, tempUser.id]
            }) if history_description.present?

          end
        rescue Exception => e
        end

        @profile.update!(profile_params)
        attributes = tempProfile.attributes
        attributes["id"] = attributes["user_id"]
        send_updates_to_webhooks(current_company, {event_type: 'profile_changed', attributes: attributes, params_data: params, profile_update: true})
        ::IntegrationsService::UserIntegrationOperationsService.new(tempUser, ['namely']).perform('update', params)
        respond_with @profile, serializer: ProfileSerializer
      end

      private

      def profile_params
        params.permit(:id, :facebook, :twitter, :linkedin, :github, :about_you, :user_id)
      end
    end
  end
end
