class BulkOnboardingAssignDocumentsJob
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 0, backtrace: true

  def perform(pt_dur, users_ids, created_by_id, company_id, user_tokens)
    return unless users_ids.present?
    company = Company.find_by(id: company_id)
    @users = company.users.where(id: users_ids)
    PaperworkRequest.where(user_id: users_ids).draft_requests.destroy_all if users_ids.present?
    packet_data = {}
    
    pt_dur.each do |doc|
      if doc['document_connection_relation_id'] # upload request
        ::BulkOnboarding::AssignUploadRequestJob.perform_async(users_ids, doc, created_by_id, company.id, user_tokens)
      elsif !doc['packet_id'] #Signatory Document without packet
        HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(doc['paperwork_template_id'], @users, created_by_id, company, nil, [], nil, user_tokens)
      else # Signatory Document with packet
        if packet_data.has_key?(doc['packet_id'])
          packet_data[doc['packet_id']].push(doc['paperwork_template_id'])
        else
          packet_data.merge!(doc['packet_id'] => [doc['paperwork_template_id']])
        end
      end
    end

    if packet_data.present?
      packet_data.each do |packet|
        paperwork_packet = company.paperwork_packets.find(packet.first)
        add_packet_docs_to_hellosign_queue(packet, @users, created_by_id, company, paperwork_packet, user_tokens)        
      end
    end
  end

  private

  def add_packet_docs_to_hellosign_queue(packet, users, created_by_id, company, paperwork_packet, user_tokens)
    return unless company

    single_sign_doc_ids = []
    packet.second&.each do |template_id|
      paperwork_template = company.paperwork_templates&.find_by_id(template_id)
      next unless paperwork_template
      
      if paperwork_packet.bulk? && !paperwork_template.is_cosigned?
        single_sign_doc_ids << template_id
      else
        HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(
          template_id, 
          users, 
          created_by_id, 
          company, 
          nil, 
          packet.second, 
          paperwork_packet, 
          user_tokens
        )
      end
    end
    
    if single_sign_doc_ids.length.positive?
      users&.each do |user|
        paperwork_template = company.paperwork_templates&.find_by_id(single_sign_doc_ids.first)
        next unless paperwork_template

        document = company.documents.find_by(id: paperwork_template.document_id)
        next unless document

        attributes = { 
          document_id: document.id, 
          user_id: user['id'], 
          requester_id: created_by_id, 
          document_token: user_tokens,
          template_ids: single_sign_doc_ids, 
          paperwork_packet_id: paperwork_packet.id, 
          paperwork_packet_type: paperwork_packet.packet_type
        }

        paperwork_request = PaperworkRequest.new(attributes)
        paperwork_request.save!(validate: false)
        next unless paperwork_request

        HellosignCall.create_embedded_signature_request_with_template_combined(
          paperwork_request.id, 
          single_sign_doc_ids, 
          user['id'], 
          company.id,
          { 'user_id': user['id'] }
        )
      end      
    end
  end
end
