module Api
  module V1
    module Admin
      class DocumentUploadRequestsController < BaseController
        include HistoryHandler
        
        before_action only: [:index , :simple_index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        before_action only: [:simple_index] do
          ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params[:sub_tab])
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        load_and_authorize_resource except: [:index, :create]
        authorize_resource only: [:index, :create]

        def index
          collection = DocumentUploadRequestsCollection.new(collection_params)
          respond_with collection.results, each_serializer: DocumentUploadRequestSerializer::Base, include: "**"
        end

        def show
          respond_with @document_upload_request, serializer: DocumentUploadRequestSerializer::Base
        end

        def simple_index
          collection = DocumentUploadRequestsCollection.new(collection_params)
          respond_with collection.results, each_serializer: DocumentUploadRequestSerializer::Simple
        end

        def paginated_index
          collection = DocumentUploadRequestsCollection.new(upload_request_paginated_params)
          results = collection.results

          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.count,
            recordsFiltered: collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: DocumentUploadRequestSerializer::Base)
          }

        end

        def documents_count
          collection = DocumentUploadRequestsCollection.new(collection_params)
          respond_with collection.results.length
        end

        def create
          save_and_respond_with_form
          create_document_history(current_company, current_user, document_upload_request_params[:document_connection_relation][:title], 'add')
        end

        def update
          save_and_respond_with_form
          create_document_history(current_company, current_user, @document_upload_request&.document_connection_relation&.title, 'update')
        end

        def save_and_respond_with_form
          documentUploadRequest = DocumentUploadRequestForm.new(document_upload_request_params)
          documentUploadRequest.save!
          respond_with documentUploadRequest, serializer: DocumentUploadRequestSerializer::Base
        end

        def destroy
          @document_upload_request.destroy!
          head 204
          create_document_history(current_company, current_user, @document_upload_request.document_connection_relation&.title, 'delete')
        end
        #:nocov:
        def paginated
          collection = DocumentConnectionRelationsCollection.new(collection_params)
          meta = {
            upload_data: collection.meta_without_duplicate_keys,
            total_open_uploads: collection.total_open_uploads
          }
          respond_with collection.results,
                       each_serializer: DocumentConnectionRelationSerializer::Dashboard,
                       meta: meta,
                       adapter: :json
        end
        #:nocov:
        def bulk_assign_upload_requests
          connection_relation_id_array = current_company.document_upload_requests.where(id: params[:upload_request_ids]).pluck(:document_connection_relation_id)
          user_id = params[:user_id]
          user = current_company.users.where(id: user_id).take rescue nil
          document_token = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base).decrypt_and_verify(params[:document_token])
          connection_relation_id_array.each do |relation_id|
            UserDocumentConnection.create({user_id: user_id , document_connection_relation_id: relation_id, company_id: current_company.id, created_by_id: current_user.id, packet_id: params[:packet_id], document_token: document_token})
          end
          
          if user.present? && params[:signatory_documents_count] == 0
            email_data = user.generate_packet_assignment_email_data(document_token)
            UserMailer.document_packet_assignment_email(email_data, current_company, user).deliver_now! if email_data.present?
          end
          head 200
        end

        def duplicate
          new_document_upload_request = @document_upload_request.duplicate_request
          respond_with new_document_upload_request, serializer: DocumentUploadRequestSerializer::Base
          create_document_history(current_company, current_user, new_document_upload_request.document_connection_relation&.title, 'add')
        end

        protected
        def document_upload_request_params
          params.permit(:id, :global, :special_user_id, :position, :user_id, document_connection_relation: [:id, :title, :description]).merge(company_id: current_company.id, meta: params[:meta], updated_by_id: params[:updated_by_id])
        end

        def collection_params
          params.merge(company_id: current_company.id, onboarding_plan: current_company.onboarding?)
        end

        def upload_request_paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          sort_column = params["columns"][params["order"]["0"]["column"]]["data"]
          sort_order = params["order"]["0"]["dir"]
          if sort_column == ""
            if params["order"]["0"]["column"] == "0"
              sort_column = "type"
            else params["order"]["0"]["column"] == "1"
              sort_column = "title"
            end
          end

          if params["term"]
            term = params["term"]
          elsif !params["search"]["value"].empty?
            term = params["search"]["value"]
          else
            term = nil
          end

          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order,
            term: term
          )
        end
      end
    end
  end
end
