class HandleHellosignCallJob
  include Sidekiq::Worker
  sidekiq_options queue: :hellosign_call, retry: 0, backtrace: true

  def perform
    # Get signature request calls
    hellosign_calls = HellosignCall.where('api_end_point = ? AND state = ?',
      'signature_request_files', 
      HellosignCall.states[:in_progress]).order(:created_at).limit(5)

    # Get highest priority calls
    hellosign_calls = hellosign_calls + HellosignCall.where('priority = ? AND state = ? AND api_end_point != ?',
      HellosignCall.priorities[:high], 
      HellosignCall.states[:in_progress],
      'signature_request_files').order(:created_at).limit(15-hellosign_calls.count)
        
    # Get medium priority calls
    hellosign_calls = hellosign_calls + HellosignCall.where('priority = ? AND state = ? AND call_type = ?',
      HellosignCall.priorities[:medium], 
      HellosignCall.states[:in_progress],
      HellosignCall.call_types[:individual]).order(:created_at).limit(15-hellosign_calls.count) if hellosign_calls.count < 15
    
    # Get remaining signature request calls
    hellosign_calls = hellosign_calls + HellosignCall.where('api_end_point = ? AND state = ?',
      'signature_request_files', 
      HellosignCall.states[:in_progress]).where.not(id: hellosign_calls.pluck(:id)).order(:created_at).limit(15-hellosign_calls.count).offset(5) if hellosign_calls.count < 15
    
    hellosign_calls.try(:each) do |hellosign_call|
      if hellosign_call.individual?
        if ['update_template_files', 'bulk_send_job_information'].include?(hellosign_call.api_end_point)
          paperwork_request = nil
        else
          paperwork_request = PaperworkRequest.find_by(id: hellosign_call.paperwork_request_id)
          unless paperwork_request.present?
            hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'N/A', error_description: "Paperwork request is not present", error_category: HellosignCall.error_categories[:user_sapling])
            next
          end
        end
        HellosignManager::IndividualHellosignCalls::HellosignCalls.call(hellosign_call, paperwork_request)
      end
    end
  end
end
