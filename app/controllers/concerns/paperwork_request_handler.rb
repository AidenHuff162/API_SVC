module PaperworkRequestHandler
  extend ActiveSupport::Concern

  def trigger_manage_hellosign_webhook_job(signature_request_id, event_type)
    ::Hellosign::HandleHellosignWebhooksJob.perform_in(10.seconds, signature_request_id, event_type)
  end
end
