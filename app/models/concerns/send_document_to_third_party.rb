module SendDocumentToThirdParty
  extend ActiveSupport::Concern

  def send_document_to_third_parties
    return unless user&.active?

    begin
      send_document_to_workday if user.workday_id
      send_document_to_bamboo if user.bamboo_id
    rescue Exception => e
      create_log('Workday', {error: e.message})
    end
  end

  private

  def get_document_type
    #return 'form_i_9_request' if i_9_document?

    {
      UserDocumentConnection: 'upload_request',
      PaperworkRequest: 'paperwork_request'
    }[self.class.name.to_sym]
  end

  def send_document_to_workday
    doc_type = get_document_type
    if doc_type == 'upload_request'
      attached_files.find_each { |file| HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob.perform_later(user.id, [doc_type], { doc_id: id, file_id: file.id }) }
    else
      HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob.perform_later(user.id, [doc_type], { doc_id: id, file_id: nil })
    end
  end

  def proceed_to_bamboo?
    self.class.name == 'UserDocumentConnection' && user.company.integration_types.include?('bamboo_hr')
  end

  def send_document_to_bamboo
    ::HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.perform_later(self, user, 'document_upload_request_file') if proceed_to_bamboo?
  end

  def create_log(integration, params)
    LoggingService::GeneralLogging.new.create(user.company, "Failed - Send document to #{integration}", params)
  end

  def i_9_document?
    document.title&.include?('(I-9)')
  end
end

