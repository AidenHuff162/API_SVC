class HrisIntegrationsService::AdpWorkforceNowU::PopSugar::ParamsBuilder < HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder

  def build_applicant_onboard_params(data)
    params = super(data)
    return {} unless params.present?

    params[:events].first[:data][:transform][:applicant][:person][:customFieldGroup] = {stringFields: [
      { stringValue: data[:business_title][:string_value], nameCode: { codeValue: data[:business_title][:code_value]} } 
    ]}

    params
  end

  def build_change_business_title_custom_field_params(data)
    build_change_string_custom_field_params(data)
  end
end