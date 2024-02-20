class AtsIntegrationsService::Lever::OfferDataBuilder
  
  delegate :offer_data_params_mapper, to: :params_mapper
  delegate :create, to: :logging_service, prefix: :log
  delegate :fetch_user_from_lever, :format_start_date, :is_team_selected?, to: :helper_service

  def get_offer_data(opportunity_id, api_key, company, integration)
    begin
      offers_response = initialize_endpoint_service.lever_webhook_endpoint(opportunity_id, api_key, '/offers')
      offer_fields_data = offers_response['data'].last rescue nil
      log_create(company, 'Lever', "Get Offer Data-#{opportunity_id}", offers_response, 200, '/offers')
      return nil unless offer_fields_data.present?

      offer_data = build_data(offer_fields_data, company, opportunity_id, api_key, integration)
      offer_data[:start_date] = format_start_date(company, offer_data[:start_date], 'offer_data')
      offer_data
    rescue Exception => e
      log_create(company, 'Lever', "Get Offer Data-#{opportunity_id}", {}, 500, '/offers', e.message)
      return nil
    end
  end

  def build_data(offer_data, company, opportunity_id, api_key, integration)
    data = {}
    custom_fields = []
    offer_data = offer_data['fields'] if offer_data['fields'].present?

    if offer_data.present?
      team_identifier = is_team_selected?(integration) ? 'team' : 'department' 

      params_mapper = offer_data_params_mapper({team_identifier: team_identifier})
      
      params_mapper.each do |key, value|
        field = nil
        identifier = value[:identifier].split('|')
        field = offer_data.try(:select) { |form_field| form_field['identifier'] == identifier[0] || form_field['identifier'] == identifier[1] }
        if field.present?
          data.merge!("#{key}": field[0]['value']) if ['default', 'both'].include?(value[:field_category])
          offer_data = offer_data - field if value[:field_category] == 'default'
        end
      end
    end

    if offer_data.present?
      for field in offer_data
        if ['toptal', 'clari'].include?(company.subdomain)
          if field['text'].present?
             coworker_field = company.custom_fields.where('name ILIKE ? AND field_type = ?', field['text'], CustomField.field_types[:coworker]).take
            if coworker_field.present? && coworker_field.coworker?
              if field['value'].present?
                lever_user = fetch_user_from_lever(opportunity_id, api_key, field['value'], company)

                if lever_user.present?
                  employee = company.users.where("email ILIKE ? OR personal_email ILIKE ?", lever_user, lever_user).take
                  if employee.blank?
                    employee = company.users.where("CONCAT_WS(' ', first_name, last_name) ILIKE ?", lever_user).take
                    if employee.blank?
                      employee = company.users.where("CONCAT_WS(' ', preferred_name, last_name) ILIKE ?", lever_user).take
                    end
                  end

                  if employee.present?
                    field['employee_id'] = employee.id
                    field['first_name'] = employee.first_name
                    field['last_name'] = employee.last_name
                    field['preferred_name'] = employee.preferred_name
                  end
                end
              end
            end
          end
        end

        custom_fields.push(field)
      end
    end

    data.merge!({lever_custom_field: custom_fields}) if custom_fields.present?
    data
  end

  def initialize_endpoint_service
    AtsIntegrationsService::Lever::Endpoint.new
  end

  def helper_service
    AtsIntegrationsService::Lever::Helper.new
  end

  def params_mapper
    AtsIntegrationsService::Lever::ParamsMapper.new
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end
end
