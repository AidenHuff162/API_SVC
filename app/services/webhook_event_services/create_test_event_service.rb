module WebhookEventServices
  class CreateTestEventService
    attr_reader :company, :params_builder

    def initialize(company, webhook, user)
      @company = company
      @webhook = webhook
      @user = user
      @params_builder = initialize_params_builder_service
    end

    def perform
      return unless @webhook.present?
      
      create_webhook_events
    end

    private

    def create_webhook_events
      event_data = {type: 'test_event', action: 'test'}
      event_data = event_data.with_indifferent_access
      begin
        test_webhook_event = @webhook.webhook_events.create!(
          triggered_for_id: @user.id,
          company_id: @webhook.company_id,
          request_body: params_builder.prepare_test_event_params(@company, event_data, @webhook),
          triggered_by_id: @user.id,
          status: WebhookEvent.statuses[:pending],
          is_test_event: true)
      rescue Exception => e
        test_webhook_event.update_columns(status: WebhookEvent.statuses[:failed], response_status: 500, triggered_at: DateTime.now, response_body: { data: e.message })
      end
    end

    def initialize_params_builder_service
      WebhookEventServices::TestParamsBuilderService.new
    end
  end
end