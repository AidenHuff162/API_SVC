class HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::DataBuilder < HrisIntegrationsService::AdpWorkforceNowU::DataBuilder
  attr_reader :custom_fields

  # {"codeValue"=>"9200058821676_116", "shortName"=>"Dayforce User?"}, 
  # {"codeValue"=>"9200058821676_117", "shortName"=>"Division"}, 
  # {"codeValue"=>"9200058821676_118", "shortName"=>"Gender Identity"}, 
  # {"codeValue"=>"9200058821676_119", "shortName"=>"People Manager?"}, 
  # {"codeValue"=>"9200058821676_120", "shortName"=>"Personal Pronoun"}, 
  # {"codeValue"=>"9200058821676_121", "shortName"=>"Retail District"}, 
  # {"codeValue"=>"9200058821676_122", "shortName"=>"Sub Department"}

  def initialize(enviornment)
    super(enviornment)

    @custom_fields = {
      people_manager: {
        adp_code_value: '9200481195666_118',
        adp_short_name: 'People Manager?',
        adp_item_id: '1586553189867928_3194'

      },
      dayforce_user: {
        adp_code_value: '9200481195666_121',
        adp_short_name: 'Dayforce User?',
        adp_item_id: '1586553189892910_2970'
      },
      personal_pronoun: {
        adp_code_value: '9200481195666_122',
        adp_short_name: 'Personal Pronoun',
        adp_item_id: '9200011471718_2040'
      },
      gender_identity: {
        adp_code_value: '9200481195666_119',
        adp_short_name: 'Gender Identity',
        adp_item_id: '9200011471718_2039'
      },
      sub_department: {
        adp_code_value: '9200481195666_120',
        adp_short_name: 'Sub Department',
        adp_item_id: '9200009695977_4801'
      }
    }
  end

  def build_applicant_onboard_data(user, adp_wfn_api = nil, access_token = nil, certificate = nil, version = nil)
    data = super(user, adp_wfn_api, access_token, certificate, version)

    data[:people_manager] = { string_value: user.get_custom_field_value_text('People Manager?').to_s, code_value: @custom_fields[:people_manager][:adp_code_value] }
    data[:dayforce_user] = { string_value: user.get_custom_field_value_text('Dayforce User?').to_s, code_value: @custom_fields[:dayforce_user][:adp_code_value] }
    data[:personal_pronoun] = { string_value: user.get_custom_field_value_text('Personal Pronoun').to_s, code_value: @custom_fields[:personal_pronoun][:adp_code_value] }
    data[:gender_identity] = { string_value: user.get_custom_field_value_text('Gender Identity').to_s, code_value: @custom_fields[:gender_identity][:adp_code_value] }
    data[:sub_department] = { string_value: user.get_custom_field_value_text('Sub Department').to_s, code_value: @custom_fields[:sub_department][:adp_code_value] }
    data
  end

  def build_change_string_custom_field_data(user, field_name, field_value)
    custom_field = {}

    case field_name
    when 'people manager?'
      custom_field = @custom_fields[:people_manager]
    when 'retail district'
      custom_field = @custom_fields[:retail_district]
    when 'dayforce user?'
      custom_field = @custom_fields[:dayforce_user]
    when 'division'
      custom_field = @custom_fields[:division]
    when 'personal pronoun'
      custom_field = @custom_fields[:personal_pronoun]
    when 'gender identity'
      custom_field = @custom_fields[:gender_identity]
    when 'sub department'
      custom_field = @custom_fields[:sub_department]
    end

    if custom_field.present?
      custom_field[:adp_string_value] = field_value
      return super(user, custom_field)
    end
  end
end
