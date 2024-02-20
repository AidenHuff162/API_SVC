class HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob < ApplicationJob
  include LoggingManagement
  queue_as :create_bamboo_documents

  def perform(document, user, document_type = 'paperwork_requests')
    return if user.bamboo_id.blank?
    document.reload
    return create_general_logging(user.try(:company), 'Upload Document to BambooHr', {api_request: 'Upload Document to BambooHr', integration_name: 'BambooHR', result: 'Document is already uploaded to BambooHr'}) if document.uploaded_to_bamboo

    response = false
    if document_type == 'document_upload_request_file'
      response = send_upload_request_document(document, user)
    elsif document_type == 'paperwork_requests'
      response = send_paperwork_request_document(document, user)
    end
    document.update(uploaded_to_bamboo: true) if response
  end

  private

  def send_upload_request_document(document, user)
    bamboo = ::HrisIntegrationsService::Bamboo::File.new(user)

    filename = "#{document.document_connection_relation.title} - #{user.first_name} #{user.last_name} (#{document.created_at.strftime('%d-%m-%Y')})"
    document_request = document.attached_files.take
    document_path = document_request.file.download_url(filename)

    bamboo.upload(document_request, document_path, filename, File.extname(document_request.original_filename))
  end

  def send_paperwork_request_document(document, user)
    if (document.present? && document.signed_document)
      bamboo = ::HrisIntegrationsService::Bamboo::File.new(user)
      
      filename = ""
      signed_date = document.sign_date.strftime("%m-%d-%Y").to_s rescue ""
      if !document.paperwork_packet_id? || (document.paperwork_packet_id? && (document.individual? || document.paperwork_packet_type == 'individual'))
        filename = "#{document.user.full_name} - #{document.document_with_deleted.title} (#{signed_date})"
      else
        filename = "#{document.user.full_name} - #{document.paperwork_packet.name} (#{signed_date})"
      end

      document_path = document.get_signed_document_url
      bamboo.upload(document, document_path, filename, '.pdf')
    end
  end
end
