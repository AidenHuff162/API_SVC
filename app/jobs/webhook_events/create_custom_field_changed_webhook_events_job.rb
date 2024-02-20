class WebhookEvents::CreateCustomFieldChangedWebhookEventsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :webhook_activities, :retry => 0, :backtrace => true
  
  def perform(company_id, custom_field_id, old_value, new_value, user_id)
    company = Company.find_by(id: company_id)
    return if company.nil?
    custom_field = company.custom_fields.find_by(id: custom_field_id)
    
    send_updates_to_webhook(company, custom_field, old_value, new_value, user_id)
  end

  private
  def send_updates_to_webhook(company, custom_field, old_value, new_value, user_id)
    if old_value != new_value
      if custom_field.field_type == 'date'
        date_format = company.get_date_format
        old_value = old_value.to_date.strftime(date_format) rescue ''
        new_value = new_value.to_date.strftime(date_format) rescue ''
      end
      values_changed = [{field_id: custom_field.api_field_id, values: { fieldName: custom_field.name.titleize, oldValue: old_value, newValue: new_value } }]
      WebhookEvents::CreateWebhookEventsJob.perform_async(company.id, {type: 'profile_changed', values_changed: values_changed, triggered_for: user_id})
      
    end
  end
end
