module Api
  module V1
    class WorkstreamsController < ApiController
      load_and_authorize_resource

      before_action :check_platform_visibility, only: :basic_index
      rescue_from CanCan::AccessDenied do |exception|
        render nothing: true, status: 204
      end

      def index
        collection = WorkstreamsCollection.new(collection_params)
        respond_with collection.results,
          each_serializer: WorkstreamSerializer::WithTasks,
          exclude_by_user_id: params[:exclude_by_user_id],
          exclude_by_owner_id: params[:exclude_by_owner_id]
      end

      def basic_index
        collection = WorkstreamsCollection.new(collection_params)
        respond_with collection.results, each_serializer: WorkstreamSerializer::Basic
      end

      def workspace_index
        collection = WorkstreamsCollection.new(collection_params)
        respond_with collection.results, each_serializer: WorkstreamSerializer::Basic
      end

      def get_custom_workstream
        unless current_company.workstreams.find_by(name: "Custom Tasks")
          current_company.create_custom_workstream
        end
        collection = WorkstreamsCollection.new(collection_params.merge(custom_tasks_workstream: true))
        respond_with collection.results, each_serializer: WorkstreamSerializer::Basic
      end

      private

      def collection_params
        params.merge(company_id: current_company.id, onboarding_plan: current_company.onboarding?)
      end

      def check_platform_visibility
        user_id = params[:user_id] || params[:owner_id] || params[:task_profile_id]
        exclude_id = params[:exclude_by_owner_id] || params[:exclude_by_user_id]
        id = user_id || exclude_id
        ::PermissionService.new.checkTaskPlatformVisibility(current_user, id)
      end
    end
  end
end
