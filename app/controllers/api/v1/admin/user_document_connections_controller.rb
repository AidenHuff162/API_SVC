module Api
  module V1
    module Admin
      class UserDocumentConnectionsController < BaseController
        before_action :require_company!
        before_action :authenticate_user!

        before_action only: [:update_state_draft_to_request, :remove_draft_connections] do
          ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, 'dashboard')
        end

        load_and_authorize_resource only: [:destroy, :update_state_draft_to_request]
        authorize_resource only: [:index, :remove_draft_connections]

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def bulk_document_assignment
          users = params.to_h[:users]
          users.each {|user| user[:document_token] = SecureRandom.uuid + "-" + DateTime.now.to_s}
          BulkDocumentAssignmentJob.perform_later(params[:document_connection_relation_id],
                                                  users,
                                                  current_user.id,
                                                  current_company.id,
                                                  params[:due_date])
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def index
          collection = UserDocumentConnectionCollection.new(collection_params)
          respond_with collection.results, each_serializer: UserDocumentConnectionSerializer::Full
        end

        def create
          if params[:smart_assignment]
            user_document_connection = UserDocumentConnection.create(user_document_connection_params.merge(smart_assignment: params[:smart_assignment], document_token: SecureRandom.uuid + "-" + DateTime.now.to_s))
          else
            user_document_connection = UserDocumentConnection.find_or_create_by(user_document_connection_params.merge(document_token: SecureRandom.uuid + "-" + DateTime.now.to_s))
            user_document_connection.email_completely_send if user_document_connection.email_not_sent?
          end
          respond_with user_document_connection, serializer: UserDocumentConnectionSerializer::Full
        end

        def destroy
          @user_document_connection.destroy!
          head 204
        end

        def update_state_draft_to_request
          @user_document_connection.request
          unless @user_document_connection.packet_id.present? && @user_document_connection.email_not_sent?
            @user_document_connection.email_completely_send
          end
        end

        def remove_draft_connections
          begin
            user = current_company.users.find_by(id: params[:user_id])
            user.user_document_connections.draft_connections.destroy_all
          rescue Exception => e
            LoggingService::GeneralLogging.new.create(current_company, 'User Document Connection - Remove Draft Connection Action', {error: e.message})
          end
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        private

        def user_document_connection_params
          params.permit(:document_connection_relation_id, :user_id, :state, :packet_id, :due_date).merge(company_id: current_company.id, created_by_id: current_user.id)
        end

        def collection_params
          params.merge(company_id: current_company.id)
        end
      end
    end
  end
end
