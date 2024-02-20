class HrisIntegrationsService::AdpWorkforceNow::Databricks::ManageAdpData
  attr_reader :user, :certificate, :access_token, :custom_fields, :request_builder, :events

  delegate :change_string_custom_field_event, to: :events, prefix: :execute
  def initialize(user, certificate = nil, access_token = nil)
    @user = user
    @access_token = access_token
    @certificate = certificate
    @company = @user.company

    @request_builder = HrisIntegrationsService::AdpWorkforceNow::Databricks::RequestBuilder.new
    @events = HrisIntegrationsService::AdpWorkforceNow::Events.new

    @custom_fields = {
      :'Annual Salary/Commissions' => {
        'nameInADP' => 'Target Variable Compensation',
        'itemId' => '273838690908_4352',
        'commissionCustomFieldId' => 7652,
        'annualBonuscustomFieldId' => 7651,
        'codeValue' => '273856406149_590'
      },
      :'Sales Draw' => {
        'nameInADP' => 'Sales Draw Annual',
        'itemId' => '273844572875_2454',
        'customFieldId' => 7653,
        'codeValue' => '273856406149_583'
      },
      :'Housing/Car Allowance' => {
        'nameInADP' => 'Car/Housing Allowance',
        'itemId' => '273844572875_2456',
        'customFieldId' => 7654,
        'codeValue' => '273856406149_582'
      },
      :'Options' => {
        'nameInADP' => 'New Hire Options',
        'itemId' => '273844572875_2457',
        'customFieldId' => 8317,
        'codeValue' => '273856406149_581'
      },
      :'RSUs' => {
        'nameInADP' => 'New Hire RSUs',
        'itemId' => '273844572875_2458',
        'customFieldId' => 7655,
        'codeValue' => '273856406149_580'
      },
      :'Sign-on Bonus' => {
        'nameInADP' => 'SignOn Bonus',
        'itemId' => '273844572875_2459',
        'customFieldId' => 7656,
        'codeValue' => '273856406149_579'
      }
    }
  end

  def update_adp_from_sapling(field_id)
    case field_id
    when 7651, 7652
      change_target_variable_fields
    when 7653
      change_sales_draw_field
    when 7654
      change_allowance_field
    when 8317
      change_new_hire_grant_option_field
    when 7655
      change_new_hire_grant_rsu_field
    when 7656
      change_sign_on_bonus
    end
  end

  def build_onboard_applicant_params (user, params = {})
    request_builder.build_onboardapplicantcustomfield_params(user, params, custom_fields)
  end

  def change_target_variable_fields
    annual_data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Annual Salary/Commissions']['annualBonuscustomFieldId'])
    commision_data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Annual Salary/Commissions']['commissionCustomFieldId'])
    custom_fields[:'Annual Salary/Commissions']['value'] = annual_data || commision_data
    params = request_builder.build_stringcustomfieldevent_params(user, custom_fields[:'Annual Salary/Commissions'])

    begin
      if params.present?
        response = execute_change_string_custom_field_event(params, access_token, certificate)
        log("Update Target Variable Compensation Field #{user.id} - SUCCESS", params, {result: response}, 200)
      end
    rescue Exception => e
      log("Update Target Variable Compensation Field #{user.id} - ERROR", params, e.message, 500)
    end
  end

  def change_sales_draw_field
    data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Sales Draw']['customFieldId'])
    custom_fields[:'Sales Draw']['value'] = data if data.present?
    params = request_builder.build_stringcustomfieldevent_params(user, custom_fields[:'Sales Draw'])

    begin
      if params.present?
        response = execute_change_string_custom_field_event(params, access_token, certificate)
        log("Update Sales Draw Field #{user.id} - SUCCESS", params, {result: response}, 200)
      end
    rescue Exception => e
      log("Update Sales Draw Field #{user.id} - ERROR", params, e.message, 500)
    end
  end

  def change_allowance_field
    data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Housing/Car Allowance']['customFieldId'])
    custom_fields[:'Housing/Car Allowance']['value'] = data if data.present?
    params = request_builder.build_stringcustomfieldevent_params(user, custom_fields[:'Housing/Car Allowance'])

    begin
      if params.present?
        response = execute_change_string_custom_field_event(params, access_token, certificate)
        log("Update Housing/Car Allowance Field #{user.id} - SUCCESS", params, {result: response}, 200)
      end
    rescue Exception => e
      log("Update Housing/Car Allowance Field #{user.id} - ERROR", params, e.message, 500)
    end
  end

  def change_new_hire_grant_option_field
    data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Options']['customFieldId'])
    custom_fields[:'Options']['value'] = data if data.present?
    params = request_builder.build_stringcustomfieldevent_params(user, custom_fields[:'Options'])

    begin
      if params.present?
        response = execute_change_string_custom_field_event(params, access_token, certificate)
        log("Update New Hire Grant option Field #{user.id} - SUCCESS", params, {result: response}, 200)
      end
    rescue Exception => e
      log("Update New Hire Grant option Field #{user.id} - ERROR", params, e.message, 500)
    end
  end

  def change_new_hire_grant_rsu_field
    data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'RSUs']['customFieldId'])
    custom_fields[:'RSUs']['value'] = data if data.present?
    params = request_builder.build_stringcustomfieldevent_params(user, custom_fields[:'RSUs'])

    begin
      if params.present?
        response = execute_change_string_custom_field_event(params, access_token, certificate)
        log("Update New Hire Grant RSU Field #{user.id} - SUCCESS", params, {result: response}, 200)
      end
    rescue Exception => e
      log("Update New Hire Grant RSU Field #{user.id} - ERROR", params, e.message, 500)
    end
  end

  def change_sign_on_bonus
    data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Sign-on Bonus']['customFieldId'])
    custom_fields[:'Sign-on Bonus']['value'] = data if data.present?
    params = request_builder.build_stringcustomfieldevent_params(user, custom_fields[:'Sign-on Bonus'])

    begin
      if params.present?
        response = execute_change_string_custom_field_event(params, access_token, certificate)
        log("Update Sign-on Bonus Field #{user.id} - ERROR", params, {result: response}, 200)
      end
    rescue Exception => e
      log("Update Sign-on Bonus Field #{user.id} - ERROR", params, e.message, 500)
    end
  end

  def log(action, request, response, status)
    LoggingService::IntegrationLogging.new.create(@company, 'ADP Workforce Now', action, request, response, status)
  end
end
