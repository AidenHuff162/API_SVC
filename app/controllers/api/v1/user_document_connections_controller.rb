module Api
  module V1
    class UserDocumentConnectionsController < ApiController
      include HistoryHandler

      before_action :require_company!
      before_action :authenticate_user!

      before_action only: [:index] do
        ::PermissionService.new.checkDocumentPlatformVisibility(current_user, params[:user_id] || current_user.id)
      end

      before_action only: [:update] do
        ::PermissionService.new.checkAccessibilityForOthers('document', current_user, params[:user_id] || current_user.id)
      end

      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      authorize_resource

      load_resource only: [:destroy]

      def index
        collection = UserDocumentConnectionCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserDocumentConnectionSerializer::Full
      end

      def update  
        user_document_connection = UserDocumentConnectionForm.new(params.merge({state: 'completed'}))
        user_document_connection&.attached_files&.first&.record&.skip_scanning = true
        user_document_connection.save
        user = current_company.users.find_by(id: params[:user_id])
        if user && user.stage_onboarding?
          user.onboarding!
        end
        respond_with user_document_connection.record, serializer: UserDocumentConnectionSerializer::Full, include: '**'
        create_document_history(current_company, current_user, user_document_connection.record&.document_connection_relation&.title, 'complete')
      end

      def destroy
        @user_document_connection.destroy!
        head 204
      end

      private
      def user_document_connection_params
        params.permit(:id, :attached_files, :user_id, :state).merge(company_id: current_company.id)
      end

      def collection_params
        user_id = params[:user_id] || current_user.id
        params.merge(user_id: user_id, company_id: current_company.id)
      end
    end
  end
end
