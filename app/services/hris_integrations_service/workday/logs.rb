module HrisIntegrationsService::Workday::Logs

  attr_reader :error

  def log(action, result, api_request, status)
    LoggingService::IntegrationLogging.new.create(
      company,
      'Workday',
      action,
      api_request,
      result,
      status
    )
  end

  def success_log(action, result={}, api_request={})
    log("SUCCESS - #{action}", result, api_request, 200)
  end

  def error_log(action, result={}, api_request={})
    result = build_result(result)
    log("FAIL - #{action}", result, api_request, 500)
    send_to_teams(action, result[:msg])
  end

  def log_statistics(status)
    # status: success or failed
    RoiManagementServices::IntegrationStatisticsManagement.new.send("log_#{status}_hris_statistics", company)
  end

  def exception_results_hash
    {
      msg: error&.message,
      backtrace: build_backtrace
    }
  end

  def build_result(result)
    result.blank? ? exception_results_hash : exception_results_hash.merge(result)
  end

  def build_backtrace
    error.backtrace.first.gsub(Rails.root.to_s, '') rescue nil
  end

  def log_result(status_code)
    status_code == 200 ? 'SUCCESS -' : 'FAIL - Unable to'
  end

  def api_action(operation_name, req_params)
    {
      Action: operation_name,
      Params: req_params
    }
  end

  def replace_logging_content(body, type, key)
    return unless body.present? && key.present? && type.present?

    worker_photo_data = body.dig(*content_dig_hash[type])
    worker_photo_data.key?(key) ? (worker_photo_data[key] = 'content replaced while logging') : nil
  end

  def content_dig_hash
    {
      response_photo: %i[get_worker_photos_response response_data worker_photo worker_photo_data],
      request_photo: %i[Person_Photo_Data Photo_Data],
      request_file: %i[Worker_Document_Data]
    }
  end

  def send_to_teams(message, error_message='Processing error by Workday')
    params = { integration_name: 'Workday', configure_app: 'teams',
               channel: "Workday Alerts - #{Rails.env.production? ? 'Production' : 'Staging'}" }
    IntegrationErrorSlackWebhook.find_by(params)&.send_notification(teams_error_message(message, error_message))
  end

  def teams_error_message(action, error_message)
    "#{company.name} | #{action} | (#{error_message})"
  end

  def log_to_wd_teams_channel(user, msg_info, channel_name)
    params = { integration_name: 'Workday', configure_app: 'teams', channel: channel_name }
    message = "#{user.company.name} | UserID:#{user.id}, WID:#{user.workday_id}, UTCTime: #{DateTime.now} | #{msg_info}"
    IntegrationErrorSlackWebhook.find_by(params)&.send_notification(message)
  end

end
