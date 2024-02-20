module Documents
  class FixBuggySignedDocumentsInBatchesJob
    include Sidekiq::Worker
    sidekiq_options queue: :document_validator, retry: false, backtrace: true

    def perform(requests_ids, batch_size)
      PaperworkRequest.where(id: requests_ids.take(batch_size)).try(:find_each) do |paperwork_request|
        ::Documents::ValidateBuggySignedDocuments.new(paperwork_request).perform
      end
      requests_ids -= requests_ids[...batch_size]
      ::Documents::FixBuggySignedDocumentsInBatchesJob.perform_in(1.minute, requests_ids, batch_size) if requests_ids.size > 0  
    end
  end
end
