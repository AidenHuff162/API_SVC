module Api
  module V1
    class SubTaskUserConnectionsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      load_and_authorize_resource except: [:index]

      def index
        collection = SubTaskUserConnectionsCollection.new(sub_task_user_connection_with_connection_id_params)
        respond_with collection.results, each_serializer: SubTaskUserConnectionSerializer::Base
      end

      def update
        @sub_task_user_connection.update!(sub_task_user_connection_params)
        respond_with @sub_task_user_connection, serializer: SubTaskUserConnectionSerializer::Base
      end

      private
      def sub_task_user_connection_with_connection_id_params
        params.permit(:task_user_connection_id)
      end

      def sub_task_user_connection_params
        params.permit(:state)
      end
    end
  end
end
