module WebhookEventServices
  class CreateProfileChangedEventsService
    attr_reader :company, :user_attributes, :params, :profile_update
    
    delegate :fetch_users, :get_values_changed, to: :helper_service

    def initialize(company, user_attributes, params, profile_update=false)
      @company = company
      @user_attributes = user_attributes
      @params = params
      @profile_update = profile_update
    end

    def perform
      create_webhook_events
    end

    private

    def create_webhook_events
      values_changed = get_values_changed(company, Webhook::PROFILE_SECTIONS, user_attributes, params, profile_update)
      WebhookEvents::CreateWebhookEventsJob.perform_async(company.id, {type: 'profile_changed', values_changed: values_changed, triggered_for: user_attributes['id']}) if values_changed.present?
    end

    def helper_service
      WebhookEventServices::HelperService.new
    end
  end
end