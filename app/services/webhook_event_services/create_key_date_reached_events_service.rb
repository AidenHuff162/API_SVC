module WebhookEventServices
  class CreateKeyDateReachedEventsService
    attr_reader :company, :current_date
    
    delegate :fetch_users, to: :helper_service

    def initialize(company)
      @company = company
      @current_date = company.time.to_date
    end

    def perform
      create_webhook_events
    end

    private

    def create_webhook_events
      fetch_users(company, company.time.to_date).try(:each) do |user_id| 
        WebhookEvents::CreateWebhookEventsJob.perform_async(company.id, {type: 'key_date_reached', triggered_for: user_id})
      end
    end

    def helper_service
      WebhookEventServices::HelperService.new
    end
  end
end