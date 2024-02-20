module Api
  module V1
    class LocationsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      before_action only: [:people_page_index] do
        ::PermissionService.new.checkPeoplePageVisibility(current_user)
      end

      load_and_authorize_resource except: [:states]

      def index
        respond_with @locations.where(active: true).includes(:users, :owner),  each_serializer: LocationSerializer::People
      end

      def basic_index
        respond_with @locations.where(active: true).order('name ASC'), each_serializer: LocationSerializer::Basic
      end

      def report_index
        locations = @locations
        if current_user.admin? && !current_user.user_role.location_permission_level.include?('all')
          locations = @locations.where(id: current_user.user_role.location_permission_level.reject(&:empty?).uniq)
        end
        respond_with locations, each_serializer: TeamSerializer::Basic
      end

      def people_page_index
        respond_with @locations.where(active: true).includes(:users, :owner),  each_serializer: LocationSerializer::Basic
      end

      def states
        country_name = params['country_name'].downcase rescue nil
        country_states = ''
        if country_name.present?
          country = ISO3166::Country.find_country_by_any_name(country_name)
          if country_name.eql?('united kingdom')
            country_states = country.states.collect { |key, value| value.name }
          elsif country && country.states
            country_states = country.states.collect { |key, value| key }
          end
        end
        respond_with country_states.to_json
      end
    end
  end
end
