class LoggingService::WebhookLogging < LoggingService::Base

  def create(company, integration_name, action, data_received, status, location, error=nil)
    if ['test', 'development'].exclude?(Rails.env)
      payload = generate_payload(company, integration_name, action, data_received, status, location, error)
      send_message(payload)
    else
      puts "Date Received: #{data_received}"
      puts "Action: #{action}"
      puts "Status: #{status}"
      puts "Status: #{status}"
    end
  end

  private

  def formated_data(company, integration_name, action, data_received, status, location, error)
    [['company_id', company&.id.try(:to_s)],
     ['company_name', company&.name],
     ['company_domain', company&.domain],
     ['integration', integration_name],
     ['action', action],
     ['data_received', data_received],
     ['error_message', error],
     ['status', status.to_s],
     ['location', location]]
  end

  def generate_payload(company, integration_name, action, data_received, status, location, error)
    data = formated_data(company, integration_name, action, data_received, status, location, error)
    message_attributes = create_message_attributes(data)
    return { queue_url: ENV['LOGGING_SERVICE_SQS'],
      message_body: "Webhook",
      message_attributes: message_attributes
    }
  end
end
