module HellosignManager
  module IndividualHellosignCalls
    class HellosignCalls < ApplicationService
      delegate :rescue_data, :check_failed_state, :create_general_logging, to: :hellosign_service

      def initialize(hellosign_call, paperwork_request)
        @hellosign_call = hellosign_call
        @paperwork_request = paperwork_request
      end

      def call
        begin
          "HellosignManager::IndividualHellosignCalls::#{api_endpoints[@hellosign_call.api_end_point.to_sym]}".constantize.call(
            @hellosign_call, @paperwork_request
          )
        rescue Exception => e
          create_general_logging({ error: e.message }.merge(rescue_data(e)))
          @hellosign_call.update(rescue_data(e).merge(state: HellosignCall.states[:failed],
                                                      error_description: e.message)) if check_failed_state(e)
        end
      end

      def api_endpoints
        {
          bulk_send_job_information: 'BulkSendJobInformation',
          create_embedded_signature_request_with_template_combined: 'EmbeddedSignatureRequestWithTemplateCombined',
          create_embedded_signature_request_with_template: 'EmbeddedSignatureRequestWithTemplate',
          firebase_signed_document: 'FirebaseSignedDocument',
          signature_request_files: 'SignatureRequestFile',
          update_signature_request_cosigner: 'UpdateSignatureRequestCosigner',
          update_template_files: 'UpdateTemplateFiles'
        }
      end

      private
        attr_reader :hellosign_call, :paperwork_request

      def hellosign_service
        ::HellosignManager::IndividualHellosignCalls::HellosignService.new(hellosign_call, paperwork_request)
      end
    end
  end
end
