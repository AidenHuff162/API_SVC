class LoggingService::Base

  def send_message(payload)
    return unless payload.present?
    payload_size = payload.to_s.bytesize
    
    if Rails.env.staging? && payload_size < 250000
      payload.delete(:queue_url) if payload[:queue_url].present?
      send_s3_object(payload)
    elsif Rails.env.production? && payload_size > 250000
      payload.delete(:queue_url) if payload[:queue_url].present?
      send_s3_object(payload)
    else
      send_sqs_message(payload)
    end
  end

  def create_message_attributes(data)
  	payload = {}
    data.try(:each) do |attribute|
      attribute[1] = set_payload_attribute(attribute)

      payload.merge!({
	  		"#{attribute[0]}": {
	  		 string_value: attribute[1],
	  		 data_type: 'String'
	  	}})
		end
  	
    return payload
  end

  private
  
  def sqs_client
    Aws::SQS::Client.new(region: ENV['AWS_REGION'], access_key_id: ENV['AWS_ACCESS_KEY'], secret_access_key: ENV['AWS_SECRET_KEY'])
  end

  def send_sqs_message(payload)
    sqs_client.send_message(payload)
  end

  def s3_client
    Aws::S3::Client.new(region: ENV['AWS_REGION'], access_key_id: ENV['AWS_ACCESS_KEY'], secret_access_key: ENV['AWS_SECRET_KEY'])
  end

  def send_s3_object(payload)
    s3_client.put_object(bucket: ENV['AWS_LOGGING_SERVICE_S3_BUCKET'], metadata: {key: payload[:message_body]},  key: Time.now.nsec.to_s, body: payload.to_json)
  end

  def set_payload_attribute(attribute)
    attribute[1] ||= 'None'
    [ActiveSupport::HashWithIndifferentAccess, Hash, Array].include?(attribute[1].class) ? attribute[1].to_json : attribute[1]
  end
end
