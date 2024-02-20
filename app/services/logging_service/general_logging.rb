class LoggingService::GeneralLogging < LoggingService::Base

  def create(company, action, result, type='Overall')
    if ['test', 'development'].exclude?(Rails.env)
      payload = generate_payload(company, action, result, type)
      send_message(payload)
    else
      Logging.create!(action: action,
                     result: result,
                     company_id: company&.id)
    end
  end

  private

  def formated_data(company, action, result, type)
    [['company_id', company&.id.try(:to_s)],
     ['company_name', company&.name],
     ['company_domain', company&.domain],
     ['action', action],
     ['result', result],
     ['log_type', type]]
  end

  def generate_payload(company, action, result, type)
    data = formated_data(company, action, result, type)
    message_attributes = create_message_attributes(data)

    return { queue_url: ENV['LOGGING_SERVICE_SQS'],
      message_body: "General",
      message_attributes: message_attributes
    }
  end
end
