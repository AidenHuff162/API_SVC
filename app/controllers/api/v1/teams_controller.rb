module Api
  module V1
    class TeamsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      before_action only: [:people_page_index] do
        ::PermissionService.new.checkPeoplePageVisibility(current_user)
      end

      load_and_authorize_resource

      def index
        respond_with @teams.where(active: true).includes(:users, :owner), each_serializer: TeamSerializer::People
      end

      def basic_index
        respond_with @teams.where(active: true).order('name ASC'), each_serializer: TeamSerializer::Basic
      end

      def report_index
        teams = @teams
        if current_user.admin? && !current_user.user_role.team_permission_level.include?('all')
          teams = @teams.where(id: current_user.user_role.team_permission_level.reject(&:empty?).uniq)
        end
        respond_with teams, each_serializer: TeamSerializer::Basic
      end

      def people_page_index
        respond_with @teams.where(active: true).includes(:users, :owner), each_serializer: TeamSerializer::Basic
      end

      def show
        respond_with @team, serializer: TeamSerializer::Full
      end

      def basic
        respond_with @team, serializer: TeamSerializer::Basic
      end
    end
  end
end
