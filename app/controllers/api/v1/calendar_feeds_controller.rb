module Api
  module V1
    class CalendarFeedsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!, except: [:feed]

      load_and_authorize_resource except: [:feed]

      def feed
        calendar = CalendarBuilder::Builder.new(current_company, params[:id]).call
        render plain: calendar
      end

      def index
        collection = CalendarFeedsCollection.new(calendar_feed_params)
        respond_with collection.results, each_serializer: CalendarFeedSerializer::Full
      end

      def create
        @calendar_feed.save!
        respond_with @calendar_feed, serializer: CalendarFeedSerializer::Full
      end

      def update
        @calendar_feed.update!(calendar_feed_params)
        respond_with @calendar_feed, serializer: CalendarFeedSerializer::Full
      end

      def destroy
        @calendar_feed.destroy!
        head 204
      end

      private

      def calendar_feed_params
        params.permit(:user_id, :feed_type).merge(company_id: current_company.id)
      end

    end
  end
end
