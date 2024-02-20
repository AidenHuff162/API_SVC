module Api
  module V1
    module Admin
      class WorkspacesController < BaseController
        load_and_authorize_resource except: [:index]
        authorize_resource only: [:index]

        def index
          respond_with current_company.workspaces.includes(:workspace_image,:workspace_members), each_serializer: WorkspaceSerializer::Basic
        end

        def create
          if @workspace.save
            WorkspaceEmailService::Invitations.new(current_user, @workspace, nil).invite_members
            respond_with @workspace, serializer: WorkspaceSerializer::Basic
          else
            if @workspace.errors.messages[:name].any?
              render json: {error: I18n.t('errors.workspace_already_exists')}, status: 422
            end
          end
        end

        private
        def workspace_params
          params.merge!(workspace_members_attributes: (params[:workspace_members_ids] || [{}]), company_id: current_company.id, created_by: current_user.id)
            .permit(:id, :name, :associated_email, :time_zone, :workspace_image_id, :company_id, :created_by,
              workspace_members_attributes: [:id, :member_id, :workspace_id, :member_role] )
        end
      end
    end
  end
end
