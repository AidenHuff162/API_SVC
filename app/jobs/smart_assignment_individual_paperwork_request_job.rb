class SmartAssignmentIndividualPaperworkRequestJob < ApplicationJob
  queue_as :smart_assignment_documents

  def perform(user_id, company_id, requester_id)
    current_company = Company.find_by(id: company_id)
    paperwork_requests = []
    user = current_company.users.find_by(id: user_id)
    return nil unless current_company
    if user
      user.create_general_logging(current_company, 'Create Hellosign requests', {api_request: "Create signature request with template for smart assignment", integration_name: "Hellosign", result: {paperwork_request_ids: user.paperwork_requests.draft_requests.ids, is_smart_assignment: true, user_id: user.id}})

      combine_single_sign_documents_if_required(user, company_id)
      user.paperwork_requests.reload

      user.paperwork_requests.draft_requests.where.not(paperwork_packet_id: nil)&.pluck(:paperwork_packet_id)&.uniq.try(:each) do |paperwork_packet|
        document_token = SecureRandom.uuid + "-" + DateTime.now.to_s
        user.paperwork_requests.draft_requests.where(paperwork_packet_id: paperwork_packet).update(document_token: document_token)
        user.user_document_connections.draft_connections.where(packet_id: paperwork_packet).update(document_token: document_token)
      end

      if user.paperwork_requests.draft_requests.count == 0
        document_token = SecureRandom.uuid + "-" + DateTime.now.to_s
        user.user_document_connections.draft_connections.where.not(packet_id: nil)&.pluck(:packet_id)&.uniq.try(:each) do |paperwork_packet|
          user.user_document_connections.draft_connections.where(packet_id: paperwork_packet).update(document_token: document_token)
        end
        if user.user_document_connections.draft_connections.get_assigned_sibling_requests(document_token).count > 0
          email_data = user.generate_packet_assignment_email_data(document_token)
          UserMailer.document_packet_assignment_email(email_data, current_company, user).deliver_now! if email_data.present?
        end
      end
      user.user_document_connections.draft_connections.map { |udc| udc.request }      
      user.paperwork_requests.draft_requests.try(:each) do|request|
        begin
          if request.present?
            if !is_combined_request?(request)
              if request.hellosign_signature_request_id.nil?
                user_ids = {}
                user_ids['user_id'] = user.id
                user_ids['co_signer_id'] = request.co_signer_id if request.co_signer_id.present?
                if request.document.paperwork_template&.is_manager_representative && user.manager.nil?
                  request.create_general_logging(current_company, 'Create Hellosign request', { api_request: 'Create signature request with template for smart assignment', integration_name: 'Hellosign', result: { paperwork_request_id: request.id, is_smart_assignment: true, is_manager_representative: 'manager not present' }})
                else
                  request.prepare
                  HellosignCall.create_embedded_signature_request_with_template(user_ids, request.id, true, company_id, requester_id, true)
                end
              else
                request.assign
                HellosignCall.create_signature_request_files(request.id, company_id, requester_id)
              end
            else
              request.prepare
            end
          end
        rescue Exception => e
          request.create_general_logging(current_company, 'Create Hellosign request', {api_request: "Create signature request with template for smart assignment", integration_name: "Hellosign", result: {error: e.message, paperwork_request_id: request.id, is_smart_assignment: true}})
        end
      end
      UserDocumentConnection.counter_culture_fix_counts only: :user, where: { users: { id: user_id } }, column_name: :incomplete_upload_request_count
    end
  end

  private

  def combine_single_sign_documents_if_required(user, company_id)
    paperwork_requests = user.paperwork_requests.draft_requests
    return if paperwork_requests.blank?

    combine_documents = get_combine_documents(paperwork_requests)
    return if combine_documents.blank?

    combine_documents.each do |packet_id, documents|
      document_ids = documents.map(&:id)
      template_ids = get_paperwork_template_ids(document_ids, user)
      HellosignCall.create_embedded_signature_request_with_template_combined(document_ids.first, template_ids, user.id, company_id, { 'user_id': user.id })
      document_ids.shift
      delete_unnecessary_documents(document_ids, user)
    end
  end

  def get_combine_documents(paperwork_requests)
    paperwork_requests.joins(:paperwork_packet)
                      .where(co_signer_id: nil, paperwork_packets: { packet_type: PaperworkPacket.packet_types[:bulk] })
                      .group_by(&:paperwork_packet_id)
  end

  def get_paperwork_template_ids(paperwork_request_ids, user)
    user.paperwork_requests.where(id: paperwork_request_ids).joins(document: :paperwork_template).pluck('paperwork_templates.id')
  end
  
  def delete_unnecessary_documents(paperwork_request_ids, user)
    user.paperwork_requests.where(id: paperwork_request_ids).map { |paperwork_request| paperwork_request.destroy }
  end

  def is_combined_request?(paperwork_request)
    return false unless belongs_to_paperwork_packet?(paperwork_request)

    is_paperwork_packet_bulk?(paperwork_request.paperwork_packet) && !is_co_signed?(paperwork_request)
  end

  def belongs_to_paperwork_packet?(paperwork_request)
    paperwork_request.paperwork_packet_id.present?
  end

  def is_paperwork_packet_bulk?(paperwork_packet)
    paperwork_packet.bulk?
  end

  def is_co_signed?(paperwork_request)
    paperwork_request.co_signer_id
  end
end
