module Hellosign
  class HandleHellosignWebhooksJob
    include Sidekiq::Worker
    sidekiq_options queue: :hellosign_webhooks_manager, retry: false, backtrace: true

    def perform(hellosign_signature_request_id, event_type)
      ::HellosignManager::HandleHellosignWebhooks.new(hellosign_signature_request_id, event_type).perform
    end
  end
end
