class BulkDocumentAssignmentJob < ApplicationJob
  queue_as :bulk_assign_documents

  def perform(dc_relation_id, users, created_by_id, company_id, upload_request_due_date = nil, packet_id = nil, is_last_record = false, is_packet_have_signatory_documents = false)
    allocate_document_upload_request(dc_relation_id, users, created_by_id, company_id, upload_request_due_date, packet_id, is_last_record, is_packet_have_signatory_documents)
  end

  private

  def allocate_document_upload_request(dc_relation_id, users, created_by_id, company_id, upload_request_due_date, packet_id, is_last_record, is_packet_have_signatory_documents)
    users.each do |u|
      document = UserDocumentConnection.find_or_create_by(document_connection_relation_id: dc_relation_id,
                                                          user_id: u['id'],
                                                          company_id: company_id,
                                                          created_by_id: created_by_id,
                                                          due_date: upload_request_due_date,
                                                          document_token: u['document_token'],
                                                          packet_id: packet_id)
      
      if packet_id.nil? && document.email_not_sent?
        document.email_completely_send
      else
        if is_packet_have_signatory_documents == false && is_last_record == true
          company = Company.find_by_id(company_id)
          user = company.users.where(id: u['id']).take
          email_data = user.generate_packet_assignment_email_data(u['document_token'])
          UserMailer.document_packet_assignment_email(email_data, company, user).deliver_now! if email_data.present?
        end
      end
    end
  end
end
