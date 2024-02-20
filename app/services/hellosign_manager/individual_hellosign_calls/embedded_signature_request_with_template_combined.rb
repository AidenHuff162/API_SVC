module HellosignManager
  module IndividualHellosignCalls
    class EmbeddedSignatureRequestWithTemplateCombined < HellosignService
      def call; embedded_signature_request_with_template_combined end

      private

      def create_signature_request(custom_fields, paperwork_templates)
        signer_roles = @paperwork_request.get_signer_roles
        paperwork_request_document = @paperwork_request.document
        HelloSign.create_embedded_signature_request_with_template(
          test_mode: @company.get_hellosign_test_mode,
          client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
          template_ids: paperwork_templates.pluck(:hellosign_template_id),
          subject: paperwork_request_document.title, message: paperwork_request_document.description,
          signers: signer_roles,
          custom_fields: custom_fields
        )
      end

      def hellosign_request(paperwork_templates)
        custom_fields = {}
        paperwork_templates.try(:find_each) do |paperwork_template|
          request = HelloSign.get_template(template_id: paperwork_template.hellosign_template_id)
          request.data['custom_fields'].try(:each) do |custom_field|
            custom_field_data_name = custom_field.data['name']
            custom_fields[custom_field_data_name] = @paperwork_request.merge_field_value(custom_field_data_name)
          end
        end
        create_signature_request(custom_fields, paperwork_templates)
      end

      def embedded_signature_request_with_template_combined
        paperwork_templates = @company.paperwork_templates.where(id: @hellosign_call.paperwork_template_ids)
        return hellosign_call_failed(:sapling, { description: I18n.t('hellosign.embedded_template_comb.description'), action: I18n.t('hellosign.embedded_template_comb.action') }) if paperwork_templates.length.zero?
        request = hellosign_request(paperwork_templates)
        return if fetch_signature_request_id(request).blank?

        if @hellosign_call.assign_now
          @paperwork_request.assign
          generate_signature_request_files(@paperwork_request)
        end
        hellosign_call_completed
      end
    end
  end
end
