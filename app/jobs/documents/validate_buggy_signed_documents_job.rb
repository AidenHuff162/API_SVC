module Documents
  class ValidateBuggySignedDocumentsJob
    include Sidekiq::Worker
    sidekiq_options queue: :document_validator, retry: false, backtrace: true

    def perform
      paperwork_requests = PaperworkRequest.documents_needs_fix
      paperwork_requests.try(:each) do |paperwork_request|
        ::Documents::ValidateBuggySignedDocuments.new(paperwork_request).perform
      end
    end
  end
end
