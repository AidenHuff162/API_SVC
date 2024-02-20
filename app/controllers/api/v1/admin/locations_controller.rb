module Api
  module V1
    module Admin
      class LocationsController < BaseController
        before_action :authorize_users, only: [:create, :update]

        before_action only: [:get_locations, :basic_index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        load_and_authorize_resource except: [:index, :states]
        authorize_resource only: [:index]

        def index
          respond_with current_company.locations.includes(:users, :owner).order(:name),
                       each_serializer: LocationSerializer::Short
        end

        def show
          respond_with @location, serializer: LocationSerializer::Full
        end

        def create
          @location.save!
          respond_with @location, serializer: LocationSerializer::Full
          PushEventJob.perform_later('location-created', current_user, {
            location_name: @location[:name],
            member_count: @location[:users_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.location.created', name: @location[:name], users_count: @location[:users_count])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.location.created', name: @location[:name], users_count: @location[:users_count])
          })
        end

        def update
          @location.update!(location_params)
          respond_with @location, serializer: LocationSerializer::Full
          PushEventJob.perform_later('location-updated', current_user, {
            location_name: @location[:name],
            member_count: @location[:users_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.location.updated', name: @location[:name], users_count: @location[:users_count])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.location.updated', name: @location[:name], users_count: @location[:users_count])
          })
        end

        def destroy
          PushEventJob.perform_later('location-deleted', current_user, {
            location_name: @location[:name],
            member_count: @location[:users_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.location.deleted', name: @location[:name], users_count: @location[:users_count])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.location.deleted', name: @location[:name], users_count: @location[:users_count])
          })
          @location.destroy!
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def search
          if params[:query].length > 0
            respond_with current_company.locations.where(active: true).where("lower(name) LIKE ?", "%" + params[:query].downcase.split("").join("%") + "%"), each_serializer: LocationSerializer::Basic
          end
        end

        def basic_index
          respond_with current_company.locations.order(:name).where(active: true), each_serializer: LocationSerializer::Basic
        end

        def get_locations
          respond_with current_company.locations, each_serializer: LocationSerializer::Full
        end

        def get_location_field
          respond_with current_company.prefrences["default_fields"].filter {|pf| pf["id"] == "loc"}&.first, each_serializer: LocationSerializer::Full
        end

        def paginated_locations
          collection = AdminGroupTypesCollection.new(locations_params)
          results = collection.results
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : collection.count,
            recordsFiltered: collection.nil? ? 0 : collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: LocationSerializer::Group)
          }
        end

        def states
          country_name = params['country_name'].downcase rescue nil
          country_states = ''
          if country_name.present?
            country = ISO3166::Country.find_country_by_any_name(country_name)
            if country_name.eql?('united kingdom')
              country_states = country.states.collect { |key, value| value.name }
            else
              country_states = country.states.collect { |key, value| key }
            end
          end

          puts "---------------------------------\n"*4
          puts country_states.inspect
          puts "---------------------------------\n"*4
          respond_with country_states.to_json
        end

        private

        def authorize_users
          current_company.users.where(id: user_ids).find_each do |user|
            authorize! :manage, user
          end
        end

        def location_params
          params.permit(:name, :owner_id, :description, :active)
        end

        def user_ids
          @user_ids ||= (params[:users] || []).map { |user| user[:id] }
        end

        def locations_params
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
