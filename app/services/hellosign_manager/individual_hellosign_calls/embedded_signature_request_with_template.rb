module HellosignManager
  module IndividualHellosignCalls
    class EmbeddedSignatureRequestWithTemplate < HellosignService
      attr_reader :paperwork_template
      def initialize(hellosign_call, paperwork_request)
        super
        @paperwork_template = @paperwork_request.document&.paperwork_template
      end
      def call; embedded_signature_request_with_template end

      private
      def request(signer_roles, custom_fields)
        HelloSign.create_embedded_signature_request_with_template(
          test_mode: @company.get_hellosign_test_mode,
          client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
          template_id: paperwork_template.hellosign_template_id,
          subject: @paperwork_request.document.title,
          message: @paperwork_request.document.description,
          signers: signer_roles,
          custom_fields: custom_fields
        )
      end

      def create_request
        request = HelloSign.get_template template_id: paperwork_template.hellosign_template_id
        merge_fields = request.data['custom_fields']
        custom_fields = {}

        merge_fields.each do |merge_field|
          custom_fields[merge_field.data['name']] = @paperwork_request.merge_field_value(merge_field.data['name'])
        end

        signer_roles = @paperwork_request.get_signer_roles
        request(signer_roles, custom_fields)
      end

      def hellosign_call_assign
        if @hellosign_call.assign_now
          @paperwork_request.assign
          generate_signature_request_files(@paperwork_request)
        end
        hellosign_call_completed
      end

      def hellosign_call_fail(description, action)
        @paperwork_request&.delete
        hellosign_call_failed(:user_sapling, { description: description, action: action })
      end
      def embedded_signature_request_with_template
        return hellosign_call_fail(I18n.t('hellosign.embedded_template_doc.description'), I18n.t('hellosign.embedded_template_doc.action')) if @paperwork_request&.document.blank?

        if paperwork_template.blank? || !paperwork_template.saved?
          hellosign_call_fail(I18n.t('hellosign.embedded_template.description'), I18n.t('hellosign.embedded_template.action'))
          return
        end
        return if fetch_signature_request_id(create_request).blank?

        hellosign_call_assign
      end
    end
  end
end
