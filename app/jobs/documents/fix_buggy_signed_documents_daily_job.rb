module Documents
  class FixBuggySignedDocumentsDailyJob
    include Sidekiq::Worker
    sidekiq_options queue: :document_validator, retry: false, backtrace: true

    def perform
      paperwork_ids = PaperworkRequest.documents_needs_daily_fix.ids
      ::Documents::FixBuggySignedDocumentsInBatchesJob.perform_async(paperwork_ids, 10) if paperwork_ids.size > 0
    end
  end
end
