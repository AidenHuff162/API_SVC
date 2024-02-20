module WebhookEventServices
  class CreateEventsService
    attr_reader :company, :event_data, :params_builder
    
    delegate :fetch_webhooks, :get_date_types, to: :helper_service

    def initialize(company, event_data)
      @company = company
      @event_data = event_data.with_indifferent_access
      @params_builder = initialize_params_builder_service
    end

    def perform
      return unless event_data['type'].present?
      
      create_webhook_events
    end

    private

    def create_webhook_events
      event_data.merge!(get_date_types(event_data[:triggered_for], company)) if event_data[:type] == 'key_date_reached'
      fetch_webhooks(company, event_data).try(:each) do |webhook|
        webhook.webhook_events.create!(
          triggered_for_id: event_data['triggered_for'],
          company_id: webhook.company_id,
          request_body: params_builder.build_request_params(company, event_data, webhook),
          triggered_by_id: event_data['triggered_by'],
          status: WebhookEvent.statuses[:pending])
      end
    end

    def initialize_params_builder_service
      WebhookEventServices::ParamsBuilderService.new
    end
    
    def helper_service
      WebhookEventServices::HelperService.new
    end
  end
end