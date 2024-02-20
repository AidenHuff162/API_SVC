module HellosignManager
  module IndividualHellosignCalls
    class FirebaseSignedDocument < HellosignService
      def call; firebase_signed_document end

      private

      def save_paperwork_request(signature_request_id)
        request = HelloSign.signature_request_files(signature_request_id: signature_request_id)
        tempfile = generate_temp_file(request)
        paperwork_request.signed_document = File.open(tempfile.path)
        tempfile.close
        paperwork_request.save
      end

      def sign_paperwork_request
        if paperwork_request.emp_submitted?
          paperwork_request.sign
        elsif paperwork_request.cosigner_submitted? && paperwork_request.co_signer_id
          paperwork_request.all_signed
        end
      end

      def paperwork_request_emp_signed
        (paperwork_request.emp_submitted? || paperwork_request.signed?) && paperwork_request.co_signer_id.blank?
      end

      def paperwork_request_all_signed
        (paperwork_request.cosigner_submitted? || paperwork_request.all_signed?) && paperwork_request.co_signer_id
      end

      def firebase_signed_document
        if paperwork_request_emp_signed || paperwork_request_all_signed
          signature_request_id = paperwork_request.hellosign_signature_request_id
          request = HelloSign.get_signature_request(signature_request_id: signature_request_id)

          unless request.data['is_complete']
            hellosign_call_failed(:hellosign, { description: I18n.t('hellosign.firebase.description_not_completed') })
            return
          end

          save_paperwork_request(signature_request_id)
          sign_paperwork_request

          generate_firebase("paperwork_request/#{signature_request_id}", paperwork_request.get_signed_document_url)
          paperwork_request.send_document_to_bamboo

        else
          hellosign_call_failed(:sapling, { description: I18n.t('hellosign.firebase.description_already_updated') })
        end
      end
    end
  end
end
