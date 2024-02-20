module HellosignManager
  module IndividualHellosignCalls
    class HellosignService < ApplicationService
      attr_reader :hellosign_call, :paperwork_request, :company

      ERROR_NAMES = ['MissingAttributes', 'MissingCredentials', 'Parsing', 'BadRequest', 'Unauthorized','Forbidden',
                     'NotFound', 'MethodNotAllowed', 'Gone', 'NotSupportedType', 'FileNotFound', 'UnknownError', 'N/A' ]

      def initialize(hellosign_call, paperwork_request)
        @hellosign_call = hellosign_call
        @paperwork_request = paperwork_request
        @company = @hellosign_call.company
      end

      def fetch_signature_request_id(request)
        signature_request_id = request.data['signature_request_id']
        @paperwork_request.update(hellosign_signature_request_id: signature_request_id) if signature_request_id
      end

      def hellosign_call_completed
        @hellosign_call.update(state: :completed)
      end

      def hellosign_call_failed(category, description)
        data = {
        error_code: 'N/A',
        error_name: 'N/A',
        error_category: HellosignCall.error_categories[category]
      }
        create_general_logging(data.merge(error: description[:description]), description[:action]) if description[:action].present?
        @hellosign_call.update(data.merge(error_description: description[:description], state: :failed))
      end

      def hellosign_call_partially_completed(category, description)
        @hellosign_call.update(
          state: :partially_completed, error_code: 'N/A', error_name: 'N/A',
          error_description: description,
          error_category: HellosignCall.error_categories[category]
        )
      end

      def create_general_logging(data, action = nil)
        @general_logging ||= LoggingService::GeneralLogging.new
        data.merge!(hellosign_call_id: @hellosign_call.id)
        @general_logging.create(@company, action || error_descriptions[@hellosign_call.api_end_point.to_sym], data,
                                'Overall')
      end

      def error_descriptions
        {
          create_embedded_signature_request_with_template: 'Get template from Hellosign',
          create_embedded_signature_request_with_template_combined: 'Get template from Hellosign',
          firebase_signed_document: 'Uploading signed document to firebase',
          signature_request_files: 'Get copy of the document from Hellosign',
          update_template_files: 'Update template request with hellosign_template_id',
          update_signature_request_cosigner: 'Update signature request cosigner with hellosign_request_id'
        }
      end

      def sapling
        {
          "HelloSign::Error::Forbidden": { error_code: '403', error_name: 'Forbidden', error_category: :sapling },
          "HelloSign::Error::MissingAttributes": { error_code: 'N/A', error_name: 'MissingAttributes', error_category: :sapling },
          "HelloSign::Error::MissingCredentials": { error_code: 'N/A', error_name: 'MissingCredentials', error_category: :sapling },
          "HelloSign::Error::MethodNotAllowed": { error_code: '405', error_name: 'MethodNotAllowed', error_category: :sapling },
          "HelloSign::Error::NotFound": { error_code: '404', error_name: 'NotFound', error_category: :sapling },
          "Net::ReadTimeout": { error_code: 'N/A', error_name: 'Server ReadTimeout', error_category: :sapling },
          "HelloSign::Error::Unauthorized": { error_code: '401', error_name: 'Unauthorized', error_category: :sapling }
        }
      end

      def user_sapling
        {
          "HelloSign::Error::BadRequest": { error_code: '400', error_name: 'BadRequest', error_category: :user_sapling },
          "HelloSign::Error::FileNotFound": { error_code: 'N/A', error_name: 'FileNotFound', error_category: :user_sapling },
          "HelloSign::Error::UnknownError": { error_code: 'N/A', error_name: 'UnknownError', error_category: :user_sapling }
        }
      end

      def hellosign
        {
          "HelloSign::Error::BadGateway": { error_code: '502', error_name: 'BadGateway', error_category: :hellosign },
          "HelloSign::Error::Conflict": { error_code: '409', error_name: 'Conflict', error_category: :hellosign },
          "HelloSign::Error::ExceededRate": { error_code: '403', error_name: 'ExceededRate', error_category: :hellosign },
          "HelloSign::Error::Gone": { error_code: '410', error_name: 'Gone', error_category: :hellosign },
          "HelloSign::Error::InternalServerError": { error_code: '500', error_name: 'InternalServerError', error_category: :hellosign },
          "HelloSign::Error::NotSupportedType": { error_code: '503', error_name: 'NotSupportedType', error_category: :hellosign },
          "HelloSign::Error::Parsing": { error_code: 'N/A', error_name: 'Parsing', error_category: :hellosign },
          "HelloSign::Error::PaidApiPlanRequired": { error_code: '402', error_name: 'PaidApliPlanRequired', error_category: :hellosign },
          "HelloSign::Error::ServiceUnavailable": { error_code: '503', error_name: 'ServiceUnavailable', error_category: :hellosign },
        }
      end

      def exceptions
        sapling.merge(user_sapling, hellosign)
      end
      def generate_temp_file(data)
        tempfile = Tempfile.new(['doc', '.pdf'])
        tempfile.binmode.write(data)
        tempfile.rewind
        tempfile
      end

      def generate_firebase(paperwork_request, data)
        firebase = Firebase::Client.new((ENV['FIREBASE_DATABASE_URL']).to_s, ENV['FIREBASE_ADMIN_JSON'])
        firebase.set(paperwork_request, data)
        @hellosign_call.update(state: HellosignCall.states[:completed])
      end

      def generate_signature_request_files(paperwork_request)
        HellosignCall.create_signature_request_files(paperwork_request.id, @hellosign_call.company_id,
                                                     @hellosign_call.job_requester_id)
        if paperwork_request.paperwork_packet_id.present?
          pending_requests_count = PaperworkRequest.get_pending_sibling_requests(paperwork_request.document_token).count + UserDocumentConnection.get_pending_sibling_requests(paperwork_request.document_token).count rescue -1
          if pending_requests_count.zero?
            email_data = paperwork_request.user.generate_packet_assignment_email_data(paperwork_request.document_token)
            UserMailer.document_packet_assignment_email(email_data, @hellosign_call.company,
                                                        paperwork_request.user).deliver_now! if email_data.present?
          end
        end
        update_document_email_status(paperwork_request)
      end

      def update_document_email_status(paperwork_request)
        paperwork_request.reload
        if paperwork_request.email_not_sent?
          paperwork_request.co_signer_id? ? paperwork_request.email_partially_send : paperwork_request.email_completely_send
        end
      end

      def rescue_data(e)
        exception_data = exceptions.with_indifferent_access[e.class.to_s]
        if exception_data.present?
          { error_code: exception_data['error_code'], error_name: exception_data['error_name'],
            error_category: HellosignCall.error_categories[exception_data['error_category']] }
        else
          { error_code: '500', error_name: e.class.to_s, error_category: HellosignCall.error_categories[:sapling] }
        end
      end

      def check_failed_state(e)
        exception_data = exceptions.with_indifferent_access[e.class.to_s]
        return exception_data.present? && exception_data['error_name'].in?(ERROR_NAMES)
      end
    end
  end
end
