module Api
  module V1
    class PaperworkRequestsController < ApiController
      include PaperworkRequestHandler, LoggingManagement
      
      before_action :require_company!
      before_action :authenticate_user!, except: :signed_paperwork

      before_action only: [:index, :download_document_url] do
        ::PermissionService.new.checkDocumentPlatformVisibility(current_user, params[:user_id] || current_user.id )
      end
      rescue_from CanCan::AccessDenied do |exception|
        render nothing: true, status: 204
      end

      load_and_authorize_resource

      def index
        collection = PaperworkRequestsCollection.new(collection_params)
        respond_with collection.results.includes(:document, :paperwork_packet, :paperwork_packet_deleted, :user, document: :attached_file), each_serializer: PaperworkRequestSerializer::Basic, user_id: current_user.id
      end

      def show
        respond_with @paperwork_request, serializer: PaperworkRequestSerializer::Full
      end

      def signature
        @paperwork_request.get_signature_url(params[:email])

        if @paperwork_request.errors.any?
          render json: {errors: @paperwork_request.errors.full_messages.to_sentence}, status: 3000
        else
          respond_with @paperwork_request, serializer: PaperworkRequestSerializer::Full
        end
        @paperwork_request.update_column(:hellosign_modal_opened_at, Time.now)
      end

      def download_document_url
        url = nil
        if ((@paperwork_request.state == 'signed' && !@paperwork_request.co_signer_id.present?) || ( @paperwork_request.co_signer_id && @paperwork_request.state == 'all_signed' )) && @paperwork_request.signed_document
          url = signed_documnet_url

        elsif @paperwork_request.state == 'assigned' || (@paperwork_request.co_signer_id && @paperwork_request.state == 'signed' )
          url = unsigned_documnet_url
        end

        render json: {url: url}, status: 200
      end

      def signed_paperwork
        eventData = JSON.parse(params[:json])
        if eventData['signature_request'] && eventData['event']
          event_type = eventData['event']['event_type']
          event_signature_request_id = eventData['signature_request']['signature_request_id']
          paperwork_request = PaperworkRequest.find_by(hellosign_signature_request_id: event_signature_request_id)
          trigger_manage_hellosign_webhook_job(event_signature_request_id, event_type) if paperwork_request && PaperworkRequest::HELLOSIGN_WEBHOOK_EVENTS.include?(event_type)
        end

        render json: 'Hello API Event Received', status: 200
      end

      def destroy
        @paperwork_request.destroy

        if params[:user_id].present?
          current_company.users.find(params[:user_id]).fix_counters
        else
          current_user.fix_counters
        end

        render body: Sapling::Application::EMPTY_BODY, status: 201
      end

      def submitted
        create_general_logging(current_company, "Paperwork request signed by signer -- #{@paperwork_request.id}", { api_request: 'Document signed by signer', integration_name: 'Hellosign' })
        case params['submitted_by']
        when 'employee'
          @paperwork_request.emp_submit
        when 'cosigner'
          @paperwork_request.cosigner_submit
        end
        respond_with @paperwork_request, serializer: PaperworkRequestSerializer::Full
      end

      private

      def signed_documnet_url
        return nil unless @paperwork_request.signed_document.present?
        params[:view_document].present? ? @paperwork_request.signed_document.file.url : @paperwork_request.get_signed_document_url
      end

      def unsigned_documnet_url
        return nil unless @paperwork_request.unsigned_document.present?
        params[:view_document].present? ? @paperwork_request.unsigned_document.file.url : @paperwork_request.get_unsigned_document_url
      end

      def collection_params
        user_id = params[:user_id] || current_user.id
        params.merge(company_id: current_company.id, user_id: user_id, onboard: true)
      end
    end
  end
end
