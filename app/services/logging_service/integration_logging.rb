class LoggingService::IntegrationLogging < LoggingService::Base

  def create(company, integration_name, action, request, response, status)
    if ['test', 'development'].exclude?(Rails.env) 
      payload = generate_payload(company, integration_name, action, request, response, status)
      send_message(payload)
    else
      Logging.create!(
        integration_name: integration_name,
        state: status,
        action: action,
        api_request: request,
        result: [ActiveSupport::HashWithIndifferentAccess, Hash, Array].include?(response.class) ? response.to_s : response,
        company_id: company.try(:id)
      )
    end
    send_error_notification(company, integration_name, action, status, response)
  end

  private

  def formated_data(company, integration_name, action, request, response, status)
    [['company_id', company&.id.try(:to_s)],
     ['company_name', company&.name],
     ['company_domain', company&.domain],
     ['integration', integration_name],
     ['action', action],
     ['request', request],
     ['response', response],
     ['status', status.to_s]]
  end

  def generate_payload(company, integration_name, action, request, response, status)
    data = formated_data(company, integration_name, action, request, response, status)
    message_attributes = create_message_attributes(data)

    return { queue_url: ENV['LOGGING_SERVICE_SQS'],
      message_body: "Integration",
      message_attributes: message_attributes
    }
  end

  def is_create_profile_error(company, integration_name, action, status, response)
    integration_name.present? && ["ADP Workforce Now - Production", "ADP Workforce Now - Staging", "Namely", "Paylocity", "BambooHR", "bamboo_hr", "ADP Workforce Now - US", "ADP Workforce Now - CAN", "ADP-WFN", "Workday", "GSuite", "Gusto"].include?(integration_name) &&
    response.present? && status.present? && status.to_i >= 300 && company.present? && company.error_notification_emails.present? &&
    !company.error_notification_emails.empty? && (action.include?("Create") || action.include?("Onboarding")) && !action.include?("Create Job")
  end

  def xero_integration_failure(company, integration_name, status)
    integration_name.present? && integration_name == 'Xero' && company.present? && company.error_notification_emails.present? && status.to_i >= 300
  end

  def send_error_notification(company, integration_name, action, status, response)
    SlackService::ManageSlackErrorNotification.new(integration_name, company&.name, action, response).perform if status.to_i >= 300
    
    if is_create_profile_error(company, integration_name, action, status, response)
      SendApiCallErrorNotificationJob.perform_async(company.id, integration_name, action, status, response)
    elsif xero_integration_failure(company, integration_name, status)
      UserMailer.integration_failure_notification(company, status, response[:response] || response[:message], integration_name).deliver_later!
    end
  end
end
