module HellosignManager
  module IndividualHellosignCalls
    class UpdateTemplateFiles < HellosignService
      def call; update_template_files end

      def update_hellosign_call(paperwork_template)
        request = HelloSign.update_template_files(
          template_id: paperwork_template.hellosign_template_id,
          test_mode: @company.get_hellosign_test_mode,
          paperwork_template.hellosign_file_param => [paperwork_template.document&.attached_file&.url_for_hellosign]
        )
        paperwork_template.update!(hellosign_template_id: request.data['template_id'], state: :saved)
        hellosign_call_completed
      end

      def update_template_files
        paperwork_template = PaperworkTemplate.find_by(id: @hellosign_call.paperwork_template_ids.first)
        paperwork_template ? update_hellosign_call(paperwork_template) : hellosign_call_failed(:user_sapling, { description: I18n.t('hellosign.update_temp_files.description'), action: I18n.t('hellosign.update_temp_files.action')} )
      end
    end
  end
end
