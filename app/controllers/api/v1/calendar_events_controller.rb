module Api
  module V1
    class CalendarEventsController < ApiController
      before_action :authenticate_user!
      before_action :fetch_calendar_events_specific_to_current_company
      before_action only: [:index] do
        ::PermissionService.new.checkCalendarPlatformVisibility(current_user, params[:user_id] || current_user.id )
      end
      load_and_authorize_resource
      authorize_resource only: [:show]
      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      def show
        respond_with @calendar_event, serializer: CalendarEventSerializer::CalendarEventDetailSerializer
      end

      def index
        @calendar_events = @calendarevent_class_object.fetch_calendar_events(current_user, calendar_event_params[:id],
          calendar_event_params[:location_filters], calendar_event_params[:department_filters],
          calendar_event_params[:start_date], calendar_event_params[:end_date], current_company,
          calendar_event_params[:custom_group_filters], calendar_event_params[:event_type_filters], calendar_event_params[:managers_filters])
        respond_with @calendar_events, each_serializer: CalendarEventSerializer::Full
      end

      def get_milestones
        events = CalendarEvent.joins("INNER JOIN users  ON users.id = calendar_events.eventable_id AND  calendar_events.eventable_type = 'User'")
                              .where(company_id: current_user.company_id)
                              .where.not(event_type: CalendarEvent.get_calendar_permissions(current_company))
                              .where('users.current_stage NOT IN (?)', [User.current_stages[:incomplete],User.current_stages[:departed],User.current_stages[:offboarding],User.current_stages[:last_month], User.current_stages[:last_week]]).where("calendar_events.event_start_date - ? <= 10", Date.today)
                              .where("event_start_date - ? >= 0", Date.today)
                              .where(event_type: [CalendarEvent.event_types["anniversary"], CalendarEvent.event_types["birthday"]])
                              .where("users.state = 'active' AND users.super_user = 'false' ")
                              .order('event_start_date')
        if params[:updates_page]
          respond_with events, each_serializer: CalendarEventSerializer::UpdatesPage
        else
          respond_with events, each_serializer: CalendarEventSerializer::Full
        end
      end

      private

      def calendar_event_params
        params.permit(:id, :start_date, :end_date, :location_filters, :department_filters, :custom_group_filters, :event_type_filters, :managers_filters).tap do |wl|
          wl[:location_filters] = wl[:location_filters].present? ? JSON.parse(params[:location_filters]) : []
          wl[:department_filters] = wl[:department_filters].present? ? JSON.parse(params[:department_filters]) : []
          wl[:custom_group_filters] = wl[:custom_group_filters].present? ? JSON.parse(params[:custom_group_filters]) : []
          wl[:event_type_filters] = wl[:event_type_filters].present? ? JSON.parse(params[:event_type_filters]) : []
          wl[:managers_filters] = wl[:managers_filters].present? ? JSON.parse(params[:managers_filters]) : []
        end
      end

      def fetch_calendar_events_specific_to_current_company
        @calendarevent_class_object = CalendarEvent.by_company(current_company.id)
      end

    end
  end
end
