module BulkOnboarding
  class AssignUploadRequestJob
    include Sidekiq::Worker
    sidekiq_options queue: :default, retry: 0, backtrace: true

    def perform(user_ids, document, created_by_id, company_id, user_tokens)
      begin
        user_ids.each do |id|
          user_document_connection = UserDocumentConnection.find_or_create_by!(document_connection_relation_id: document['document_connection_relation_id'],
                                                            user_id: id,
                                                            company_id: company_id,
                                                            created_by_id: created_by_id,
                                                            due_date: nil,
                                                            packet_id: document['packet_id'],
                                                            document_token: user_tokens[id.to_s])

          user_document_connection.request if user_document_connection.draft?
          user_document_connection.email_completely_send if !document['packet_id'] && user_document_connection.email_not_sent?
        end
      rescue Exception => e
        create_log(Company.find(company_id), "BulkOnboarding::AssignUploadRequestJob - UserDocumentConnection creation failed", {data: {jid: jid, document: document}, error: e.inspect})
      end
    end

    private

    def create_log(company ,action, result)
      LoggingService::GeneralLogging.new.create(company, action, result)
    end

  end
end