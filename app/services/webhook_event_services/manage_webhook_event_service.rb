module WebhookEventServices
  class ManageWebhookEventService
  
    delegate :create, to: :logging, prefix: :logs
    def initialize_event(company, event_data)
      begin
        @company_id = company.id
        @event_data = event_data.with_indifferent_access
        return unless company.present?
        if @event_data[:event_type] == 'custom_field'
          create_custom_field_changed_webhook_events_job(@company_id, @event_data[:custom_field_id], @event_data[:old_value], @event_data[:new_value], @event_data[:user_id])  
        elsif company.webhooks.existing_webhooks(event_data[:event_type]) > 0
          case @event_data[:event_type]
          when "new_pending_hire", "stage_completed", "stage_started" 
            create_webhook_events_job(@company_id, @event_data.except(:event_type)) 
          when "job_details_changed"
            create_job_details_changed_webhook_events_job(@company_id, @event_data[:attributes], @event_data[:params_data], @event_data[:data], @event_data[:ctus_name], @event_data[:effective_date]) 
          when "key_date_reached"
            create_key_date_reached_webhook_events_for_company_job(@company_id) 
          when "profile_changed"
            create_profile_changed_webhook_events_job(@company_id, @event_data[:attributes], @event_data[:params_data], @event_data[:profile_update]) 
          when 'onboarding', 'offboarding'
            create_onboarding_offboarding_webhook_event_job(@company_id, @event_data)
          end
        end
      rescue Exception => error
        event_data.merge!(error: {error_message: error.message, error_back_trace: error.backtrace})
        logging.create(company, "Trigger webhooks for #{event_data[:event_type]}", event_data)
      end
    end

    def create_webhook_events_job(company_id, event_data)
      WebhookEvents::CreateWebhookEventsJob.perform_async(company_id, event_data)
    end

    def create_custom_field_changed_webhook_events_job(company_id, custom_field_id, old_value, new_value, user_id)
      WebhookEvents::CreateCustomFieldChangedWebhookEventsJob.perform_async(company_id, custom_field_id, old_value, new_value, user_id)
    end

    def create_job_details_changed_webhook_events_job(company_id, attributes, params_data, data, ctus_name ,effective_date)
      WebhookEvents::CreateJobDetailsChangedWebhookEventsJob.perform_async(company_id, attributes, JSON.parse(params_data.to_json), data, ctus_name, effective_date)
    end

    def create_key_date_reached_webhook_events_for_company_job(company_id)
      WebhookEvents::CreateKeyDateReachedWebhhokEventsForCompanyJob.perform_async(company_id)
    end

    def create_profile_changed_webhook_events_job(company_id, attributes, params_data, profile_update=false)
      WebhookEvents::CreateProfileChangedWebhookEventsJob.perform_async(company_id, attributes, params_data.to_h, profile_update)
    end 

    def create_onboarding_offboarding_webhook_event_job(company_id, event_data)
      WebhookEvents::CreateOnboardingOffboardingWebhookEventsJob.perform_async(company_id, event_data)
    end

    def logging
      LoggingService::GeneralLogging.new
    end
  end
end