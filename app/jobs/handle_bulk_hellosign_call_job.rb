class HandleBulkHellosignCallJob
  include Sidekiq::Worker
  sidekiq_options queue: :bulk_hellosign_call, retry: 0, backtrace: true

  def perform
    # Get all low priority calls
    hellosign_calls = HellosignCall.get_hellosign_bulk_call.limit(1)
    
    hellosign_calls.try(:each) do |hellosign_call|
      paperwork_templates = PaperworkTemplate.get_saved_paperwork_templates(hellosign_call.paperwork_template_ids)
      if paperwork_templates.present?
        HandleBulkHellosignCallService.new(hellosign_call, paperwork_templates).perform
      else
        hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'N/A', error_description: "Paperwork template is not present or is not saved", error_category: HellosignCall.error_categories[:user_sapling])
        DestroyBulkPaperworkRequests.perform_async(hellosign_call.bulk_paperwork_requests.pluck('paperwork_request_id'))
      end
    end
  end
end
