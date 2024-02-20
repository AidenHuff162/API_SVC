module Api
  module V1
    module Admin
      class DocumentsController < BaseController
        include HistoryHandler
        
        load_and_authorize_resource except: [:index]
        authorize_resource only: [:index, :create, :update]

        def index
          respond_with current_company.documents, each_serializer: DocumentSerializer::Full
        end

        def create
          document = DocumentForm.new(params.merge(company_id: current_company.id))
          document&.attached_file&.record&.skip_scanning = true
          document.save!
          respond_with document, serializer: DocumentSerializer::Full
        end

        def destroy
          @document.destroy
          head 204
        end

        def update
          @document.meta = params[:meta]
          @document&.attached_file&.skip_scanning = true
          @document.update(document_params)

          respond_with @document, serializer: DocumentSerializer::Full
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.document.updated', name: document_params[:title])
          })
          create_document_history(current_company, current_user, document_params[:title], 'update')          
        end

        def show
          respond_with @document, serializer: DocumentSerializer::Full
        end
        #:nocov:
        def paginated
          
          collection = DocumentsCollection.new(collection_params)
          meta = {
            doc_data: collection.meta_without_duplicate_keys,
            total_open_documents: collection.total_open_documents
          }
          respond_with collection.results,
                       each_serializer: DocumentSerializer::Dashboard,
                       meta: meta,
                       adapter: :json
        end
        #:nocov:
        protected
        def document_params
          params.permit(:id, :attached_file, :title, :description).merge(company_id: current_company.id, meta: params[:meta])
        end

        def collection_params
          params.merge(company_id: current_company.id, meta: params[:meta])
        end

      end
    end
  end
end
