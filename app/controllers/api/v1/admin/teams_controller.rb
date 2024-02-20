module Api
  module V1
    module Admin
      class TeamsController < BaseController
        before_action :authorize_users, only: [:create, :update]
        before_action only: [:index, :basic_index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        load_and_authorize_resource except: [:index]
        authorize_resource only: [:index]

        def index
          respond_with current_company.teams.order(:name), each_serializer: TeamSerializer::Full
        end

        def show
          respond_with @team, serializer: TeamSerializer::Full
        end

        def create
          @team.save!
          respond_with @team, serializer: TeamSerializer::Full
          PushEventJob.perform_later('team-created', current_user, {
            team_name: @team[:name],
            member_count: @team[:users_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.team.created', name: @team[:name], users_count: @team[:users_count])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.team.created', name: @team[:name], users_count: @team[:users_count])
          })
        end

        def update
          @team.update!(team_params)
          respond_with @team, serializer: TeamSerializer::Full
          PushEventJob.perform_later('team-updated', current_user, {
            team_name: @team[:name],
            member_count: @team[:users_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.team.updated', name: @team[:name], users_count: @team[:users_count])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.team.updated', name: @team[:name], users_count: @team[:users_count])
          })
        end

        def destroy
          PushEventJob.perform_later('team-deleted', current_user, {
            team_name: @team[:name],
            member_count: @team[:users_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.team.deleted', name: @team[:name], users_count: @team[:users_count])
          })
          @team.destroy!
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.team.deleted', name: @team[:name], users_count: @team[:users_count])
          })
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def basic_index
          respond_with current_company.teams.order(:name).where(active: true), each_serializer: TeamSerializer::Basic
        end

        def get_teams
          respond_with current_company.teams, each_serializer: TeamSerializer::Basic
        end

        def get_team_field
          respond_with current_company.prefrences["default_fields"].filter {|pf| pf["id"] == "dpt"}&.first, each_serializer: TeamSerializer::Basic
        end

        def paginated_teams
          collection = AdminGroupTypesCollection.new(paginated_team_params)
          results = collection.results
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : collection.count,
            recordsFiltered: collection.nil? ? 0 : collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: TeamSerializer::Group)
          }
        end

        def search
          if params[:query].length > 0
            respond_with current_company.teams.where(active: true).where("lower(name) LIKE ?", "%" + params[:query].downcase.split("").join("%") + "%"), each_serializer: TeamSerializer::Basic
          end
        end

        private

        def authorize_users
          current_company.users.where(id: user_ids).find_each do |user|
            authorize! :manage, user
          end
        end

        def team_params
          params.permit(:name, :owner_id, :description, :active)
        end

        def user_ids
          @user_ids ||= (params[:users] || []).map { |user| user[:id] }
        end

        def paginated_team_params
          page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          params.merge(
                       sort_order: params[:sort_order],
                       sort_column: params[:sort_column],
                       page: page, per_page: params[:length])
        end
      end
    end
  end
end
