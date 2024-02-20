class HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ParamsBuilder < HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder

  def build_applicant_onboard_params(data)
    params = super(data)
    return {} unless params.present?

    stringFields = []
    stringFields.push({ stringValue: data[:people_manager][:string_value], nameCode: { codeValue: data[:people_manager][:code_value]} }) if data[:people_manager][:string_value].present?
    stringFields.push({ stringValue: data[:dayforce_user][:string_value], nameCode: { codeValue: data[:dayforce_user][:code_value]} }) if data[:dayforce_user][:string_value].present?
    stringFields.push({ stringValue: data[:personal_pronoun][:string_value], nameCode: { codeValue: data[:personal_pronoun][:code_value]} }) if data[:personal_pronoun][:string_value].present?
    stringFields.push({ stringValue: data[:gender_identity][:string_value], nameCode: { codeValue: data[:gender_identity][:code_value]} }) if data[:gender_identity][:string_value].present?
    stringFields.push({ stringValue: data[:sub_department][:string_value], nameCode: { codeValue: data[:sub_department][:code_value]} }) if data[:sub_department][:string_value].present?

    params[:events].first[:data][:transform][:applicant][:person][:customFieldGroup] = { stringFields: stringFields }
    
    params
  end
end