class LoggingService::SaplingApiLogging < LoggingService::Base

  def create(company, api_key, end_point, data_received, status, message, location)
    data_received = sanitize_photo_data(data_received)
    if ['test', 'development'].exclude?(Rails.env)
      payload = generate_payload(company, api_key, end_point, data_received, status, message, location)
      send_message(payload)
    else
      ApiLogging.create!(company_id: company.try(:id), api_key: api_key, end_point: end_point, data: data_received, status: status, message: message)
    end
  end

  private

  def formated_data company, api_key, end_point, data_received, status, message, location
    [['company_id', company&.id.try(:to_s)],
     ['company_name', company&.name],
     ['company_domain', company&.domain],
     ['api_key', api_key],
     ['end_point', end_point],
     ['data_received', data_received],
     ['status', status.to_s],
     ['message', message],
     ['location', location]]
  end

  def generate_payload company, api_key, end_point, data_received, status, message, location
    data = formated_data(company, api_key, end_point, data_received, status, message, location)
    message_attributes = create_message_attributes(data)

    return { queue_url:ENV['LOGGING_SERVICE_SQS'],
      message_body: "SaplingApi",
      message_attributes: message_attributes
    }
  end

  def sanitize_photo_data(data_received)
    if data_received&.class == Hash && data_received&.keys&.include?('profile_photo')
      photo_data = data_received['profile_photo']
      if photo_data&.class == ActionDispatch::Http::UploadedFile
        data_received['profile_photo'] = photo_data.original_filename rescue 'None'
      end
    end
    data_received
  end
end
