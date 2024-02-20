class HrisIntegrationsService::AdpWorkforceNow::Databricks::RequestBuilder

  def build_stringcustomfieldevent_params(user, data = {})
    params = {
      'events': [{
        'eventNameCode': {
          'codeValue': 'worker.customField.string.change'
        },
        'data': {
          'eventContext': {
            'worker': {
              'associateOID': user.adp_wfn_us_id, 
              'customFieldGroup': {
                'stringField': { 
                  'itemID': data['itemId'] 
                }
              }
            }
          },
          'transform': {
            'worker': {
              'customFieldGroup': { 
                'stringField': { 
                  'nameCode': { 
                    'shortName': data['nameInADP'] 
                  }, 
                  'stringValue': check_and_return_value(data['value'])
                }
              }
            }
          }
        }
      }]
    }

    params
  end

  def build_onboardapplicantcustomfield_params(user, params = {}, custom_fields)
    annual_data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Annual Salary/Commissions']['annualBonuscustomFieldId'])
    commision_data = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Annual Salary/Commissions']['commissionCustomFieldId']) 
    sales_draw = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Sales Draw']['customFieldId'])
    allowance = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Housing/Car Allowance']['customFieldId'])
    options = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Options']['customFieldId'])
    rsu = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'RSUs']['customFieldId'])
    sign_on = user.get_custom_field_value_text(nil, false, nil, nil, false, custom_fields[:'Sign-on Bonus']['customFieldId'])

    annual_or_commission = annual_data || commision_data

    params[:events].first[:data][:transform][:applicant][:person][:customFieldGroup] = { stringFields: [
      { stringValue: check_and_return_value(annual_or_commission), nameCode: { codeValue: custom_fields[:'Annual Salary/Commissions']['codeValue'] } },
      { stringValue: check_and_return_value(sales_draw), nameCode: { codeValue: custom_fields[:'Sales Draw']['codeValue'] } },
      { stringValue: check_and_return_value(allowance), nameCode: { codeValue: custom_fields[:'Housing/Car Allowance']['codeValue'] } },
      { stringValue: check_and_return_value(options), nameCode: { codeValue: custom_fields[:'Options']['codeValue'] } }, 
      { stringValue: check_and_return_value(rsu), nameCode: { codeValue: custom_fields[:'RSUs']['codeValue'] } }, 
      { stringValue: check_and_return_value(sign_on), nameCode: { codeValue: custom_fields[:'Sign-on Bonus']['codeValue'] }}
    ]}
    
    params
  end

  private

  def check_and_return_value(value)
    value.blank? ? "0" : value 
  end
end