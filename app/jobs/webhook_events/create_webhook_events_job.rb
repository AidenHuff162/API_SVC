class WebhookEvents::CreateWebhookEventsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :webhook_activities, :retry => 0, :backtrace => true

  def perform(company_id, event_data)
    company = Company.find_by(id: company_id)
    return if company.nil?
    WebhookEventServices::CreateEventsService.new(company, sanatize_data(event_data)).perform
  end

  private
  def sanatize_data(data)
    data&.dig('values_changed').try(:each_with_index) do |value_changed, index|
      data["values_changed"][index]["values"]["oldValue"] = convert_empty_string_to_nil(value_changed&.dig("values", "oldValue")) if value_changed&.dig("values")&.has_key?("oldValue")
      data["values_changed"][index]["values"]["newValue"] = convert_empty_string_to_nil(value_changed&.dig("values", "newValue")) if value_changed&.dig("values")&.has_key?("newValue")
    end
    data
  end

  def convert_empty_string_to_nil(value)
    value.is_a?(String) && value&.blank? ? nil : value
  end
end
