module LoggingService::LoggingHashes

  def loggings_mapper
    {
      IntegrationLogging: integration_logging_hash,
      WebhookLogging: webhook_logging_hash,
      SaplingApiLogging: sapling_api_logging_hash
    }.with_indifferent_access
  end

  def integration_logging_hash
    {
      loggings: 'IntegrationLogging',
      hash: integration_loggings_hash
    }
  end

  def webhook_logging_hash
    {
      loggings: 'WebhookLogging',
      hash: webhook_loggings_hash
    }
  end

  def sapling_api_logging_hash
    {
      loggings: 'SaplingApiLogging',
      hash: sapling_api_loggings_hash
    }
  end

  def sapling_api_loggings_hash
    {
      'company_name' => filters[:company_name],
      'end_point.contains' => filters[:end_point],
      'data_received.contains' => filters[:data_received],
      'message.contains' => filters[:message],
      'status' => filters[:status]
    }
  end

  def webhook_loggings_hash
    {
      'company_name' => filters[:company_name],
      'integration' => filters[:integration],
      'data_received.contains' => filters[:data_received],
      'error_message.contains' => filters[:error_message],
      'action.contains' => filters[:actions],
      'status' => filters[:status]
    }
  end

  def integration_loggings_hash
    {
      'company_name' => filters[:company_name],
      'integration' => filters[:integration],
      'request.contains' => filters[:request],
      'response.contains' => filters[:response],
      'action.contains' => filters[:actions],
      'status' => filters[:status]
    }
  end

end