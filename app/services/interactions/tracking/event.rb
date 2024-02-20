module Interactions
  module Tracking
    class Event
      attr_reader :client, :event_name, :user, :metadata

      def initialize(event_name, user, metadata)
        @client = Intercom::Client.new(app_id: ENV['INTERCOM_APP_ID'], api_key: ENV['INTERCOM_API_KEY'])
        @event_name = event_name
        @user = user
        @metadata = metadata
      end

      def perform
        begin
          client.events.create(options)
        rescue
          return false
        end
      end

      private

      def options
        {
          event_name: event_name,
          created_at: Time.now.to_i,
          email: user.email,
          user_id: user.id,
          metadata: metadata
        }
      end
    end
  end
end
