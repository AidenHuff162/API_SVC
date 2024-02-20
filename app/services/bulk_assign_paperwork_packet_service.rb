class BulkAssignPaperworkPacketService
  attr_reader :company, :user, :attributes

  def initialize(company, user, attributes)
    @company = company
    @user = user
    @attributes = attributes
  end

  def perform
    allocate_packet
  end

  private

  def allocate_packet
    paperwork_packet = PaperworkPacket.find_by_id(attributes[:id])
    return unless paperwork_packet.present?

    paperwork_packet_connections = paperwork_packet.paperwork_packet_connections
    return unless paperwork_packet_connections.present?

    document_upload_request_ids = paperwork_packet_connections.where(connectable_type: 'DocumentUploadRequest').pluck(:connectable_id)
    paperwork_template_ids = paperwork_packet_connections.where(connectable_type: 'PaperworkTemplate').pluck(:connectable_id)

    allocate_document_token_to_each_user(attributes[:users])
    allocate_document_upload_requests(document_upload_request_ids, is_packet_have_signatory_documents = paperwork_template_ids.count > 0) if document_upload_request_ids.present?
    allocate_paperwork_templates(paperwork_template_ids, paperwork_packet) if paperwork_template_ids.present?
  end

  def allocate_document_token_to_each_user(users)
    users.each {|user| user[:document_token] = SecureRandom.uuid + "-" + DateTime.now.to_s}
  end

  def allocate_document_upload_requests(document_upload_request_ids, is_packet_have_signatory_documents = false)
    BulkAssignDocumentUploadRequestService.new(company, user, attributes).perform(document_upload_request_ids, is_packet_have_signatory_documents)
  end

  def allocate_paperwork_templates(paperwork_template_ids, paperwork_packet)
    BulkAssignPaperworkTemplateService.new(company, user, attributes, paperwork_packet).perform(paperwork_template_ids)
  end
end