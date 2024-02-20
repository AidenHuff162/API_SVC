module PtoRequestService
  module Activity
    class CreateActivity
      attr_reader :request_object, :current_user_id, :activity_type, :includes_comments, :request_unchanged, :previous_status

      def initialize(request_object, current_user_id, activity_type, includes_comments = nil, request_unchanged = nil, previous_status = nil)
        @request_object = request_object
        @current_user_id = current_user_id
        @activity_type = activity_type
        @includes_comments = includes_comments
        @request_unchanged = request_unchanged
        @previous_status = previous_status
      end

      def perform
        case activity_type
        when 'CREATED_REQUEST'
          create_actiivty_for_request_creation
        when 'UPDATED_REQUEST'
          create_activty_for_request_update
        end
      end

      private

      def create_actiivty_for_request_creation
        request_object.create_submitted_activity(current_user_id)
        create_comment_activity if request_object.comments.present?
        request_object.create_auto_approved_activity(@current_user_id) if request_object.status == 'approved'
      end

      def create_activty_for_request_update
        create_comment_activity if includes_comments && !request_unchanged
        current_status = request_object.status
        request_object.create_status_related_activity(current_user_id, current_status, previous_status) if !request_unchanged
      end

      def create_comment_activity
        request_object.create_comment_activity(current_user_id)
      end
    end
  end
end