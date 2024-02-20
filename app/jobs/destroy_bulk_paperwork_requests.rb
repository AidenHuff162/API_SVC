class DestroyBulkPaperworkRequests
  include Sidekiq::Worker
  sidekiq_options :queue => :destroy_bulk_paperwork_requests, :retry => 0, :backtrace => true

  def perform(paperwork_request_ids)    
    if paperwork_request_ids
      paperwork_request_ids.each do |paperwork_request_id|
        PaperworkRequest.find_by_id(paperwork_request_id)&.delete if paperwork_request_id.present?
      end
    end
  end
end
