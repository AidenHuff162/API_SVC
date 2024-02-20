module Api
  module V1
    class UserRolesController < ApiController
      include ManageUserRoles
      include CustomSectionApprovalHandler

      load_and_authorize_resource
      authorize_resource only: [:index, :update, :destroy, :create, :remove_user_role, :custom_alert_page_index, :add_user_role, :create_requested_fields_for_user_role_approval]

      before_action only: [:full_index, :home_index] do
        ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
      end

      before_action only: [:update] do
        ::PermissionService.new.canUpdatePermission(@user_role, current_user)
      end
      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
      end

      def index
        collection = UserRolesCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserRoleSerializer::Basic
      end

      def custom_alert_page_index
        collection = UserRolesCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserRoleSerializer::CustomAlert
      end

      def simple_index
        collection = UserRolesCollection.new(simple_params)
        respond_with collection.results, each_serializer: UserRoleSerializer::Simple
      end

      def full_index
        collection = UserRolesCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserRoleSerializer::Full, permission: current_user.user_role.permissions['admin_visibility']['permissions']
      end

      def home_index
        collection = UserRolesCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserRoleSerializer::Home, permission: current_user.user_role.permissions['admin_visibility']['permissions']
      end

      def create
        form = UserRoleForm.new(role_params)
        form.save!
        respond_with form.user_role, serializer: UserRoleSerializer::Full
      end

      def show
        respond_with @user_role, serializer: UserRoleSerializer::Full, permission: current_user.user_role.permissions['admin_visibility']['permissions']
      end

      def destroy
        @user_role.destroy!
        head 204
      end

      def update
        prev_role = current_company.user_roles.find_by(id: @user_role.id)
        @user_role.update!(role_params)
        LogoutUserOnPermissionUpdateJob.perform_async(@user_role.id) unless @user_role.role_not_changed?(prev_role)
        respond_with @user_role, serializer: UserRoleSerializer::Update, permission: current_user.user_role.permissions['admin_visibility']['permissions']
      end

      def remove_user_role
        user = current_company.users.find_by_id(params[:user_id])
        user.remove_role
        render body: Sapling::Application::EMPTY_BODY
      end

      def add_user_role        
        respond_with assign_user_role(params[:user_id], params[:role_id]), serializer: UserRoleSerializer::Update, permission: current_user.user_role.permissions['admin_visibility']['permissions']
      end

      def create_requested_fields_for_user_role_approval
        fields = prepare_fields_for_cs_approval(params.to_h, params[:user_id], true, 'user_role')
        return unless fields.present?
        role = current_company.user_roles.find_by_id(params[:user_role_id])
        render json: { role: role , fields: fields}, status: 200
      end

      private

      def collection_params
        params.merge(company_id: current_company.id, user_ids: user_ids)
      end

      def simple_params
        params.merge!(permission_level_ids: []) if params[:permission_level_ids].nil?
        params[:permission_level_ids] += current_company.user_roles.where(role_type: UserRole.role_types["super_admin"]).pluck(:id) if current_user.user_role.role_type == "admin"
        params.merge(company_id: current_company.id)
      end

      def role_params
        params.permit(:name, :position, :description, :reporting_level, :role_type, :status_permission_level => [], :team_permission_level => [], :location_permission_level => []).merge(permissions: role_permissions, company_id: current_company.id)
      end

      def role_permissions
        @role_permissions ||= params[:permissions]
      end

      def user_ids
        @user_ids ||= (params[:users] || []).map { |user| user[:id] }
      end

      def create_log(company ,action, result)
        LoggingService::GeneralLogging.new.create(company, action, result)
      end
    end
  end
end
