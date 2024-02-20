module HellosignManager
  module IndividualHellosignCalls
    class UpdateSignatureRequestCosigner < HellosignService
      def call; update_signature_request_cosigner end

      private

      def update_hellosign_signature_request(current_cosigner, hellosign_signature_id)
        HelloSign.update_signature_request(
          signature_request_id: @paperwork_request.hellosign_signature_request_id,
          signature_id: hellosign_signature_id,
          email_address: current_cosigner.get_email, name: current_cosigner.full_name
        )
        @paperwork_request.update(co_signer_id: current_cosigner.id)
        @paperwork_request.reload

        data = {
          id: @paperwork_request.user_id, document_type: 'paperwork_request',
          document_id: @paperwork_request.id, co_signer_id: @paperwork_request.co_signer_id
        }
        Interactions::Users::DocumentAssignedEmail.new(data).perform if @paperwork_request.signed?
        hellosign_call_completed
      end

      def update_signature_request_cosigner
        current_cosigner = @company.users.find_by(id: @paperwork_request.document.paperwork_template.representative_id)
        previous_cosigner = @company.users.find_by(id: @paperwork_request.co_signer_id)

        if @paperwork_request && current_cosigner && previous_cosigner
          hellosign_signature_id = @paperwork_request.get_hellosign_signature_id(previous_cosigner.get_email)

          if hellosign_signature_id.blank?
            hellosign_call_failed(:user_sapling, { description: I18n.t('hellosign.update_sign_cosigner.description_id_blank')} )
            return
          end

          update_hellosign_signature_request(current_cosigner, hellosign_signature_id)
        else
          hellosign_call_failed(:user_sapling, { description: I18n.t('hellosign.update_sign_cosigner.description_paperwork'), action: I18n.t('hellosign.update_sign_cosigner.action')} )
        end
      end
    end
  end
end
