class BulkAssignDocumentUploadRequestService
  attr_reader :company, :user, :attributes

  def initialize(company, user, attributes)
    @company = company
    @user = user
    @attributes = attributes
  end

  def perform(document_upload_request_ids, is_packet_have_signatory_documents = false)
    return unless document_upload_request_ids.present?
    
    document_connection_relation_ids = company.document_upload_requests.where(id: document_upload_request_ids).pluck(:document_connection_relation_id)
    return unless document_connection_relation_ids.present?

    allocate(document_connection_relation_ids, is_packet_have_signatory_documents)
  end

  private

  def allocate(document_connection_relation_ids, is_packet_have_signatory_documents)
    document_connection_relation_ids_length = document_connection_relation_ids.length
    is_last_record = false
    document_connection_relation_ids.each_with_index do |document_connection_relation_id, index|
      is_last_record = true if index == document_connection_relation_ids_length - 1
      BulkDocumentAssignmentJob.perform_later(document_connection_relation_id, attributes[:users], user.id, company.id, nil, attributes[:id], is_last_record, is_packet_have_signatory_documents)
    end
  end
end
