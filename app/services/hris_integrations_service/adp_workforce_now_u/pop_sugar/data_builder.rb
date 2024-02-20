class HrisIntegrationsService::AdpWorkforceNowU::PopSugar::DataBuilder < HrisIntegrationsService::AdpWorkforceNowU::DataBuilder
  attr_reader :custom_fields

  def initialize(enviornment)
    super(enviornment)

    @custom_fields = {
      business_title: {
        adp_code_value: '401247026_2676',
        adp_short_name: 'Business Title',
        adp_item_id: '118778966_16677'
      }
    }
  end

  def build_applicant_onboard_data(user, adp_wfn_api = nil)
    data = super(user, adp_wfn_api)
    data.delete(:job_title)

    #Business title
    data[:business_title] = { string_value: user.title.to_s, code_value: @custom_fields[:business_title][:adp_code_value] }
    data
  end

  def build_change_business_title_custom_field_data(user)
    build_change_string_custom_field_data(user, @custom_fields[:business_title].merge(adp_string_value: user.title.to_s))
  end
end