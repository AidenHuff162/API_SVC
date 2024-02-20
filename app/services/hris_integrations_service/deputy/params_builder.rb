class HrisIntegrationsService::Deputy::ParamsBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_params(data, should_send_invite = false)
    params = {}

    params[:strFirstName] = data[:strFirstName]
    params[:strLastName] = data[:strLastName]
    params[:strEmail] = data[:strEmail]
    params[:strStartDate] = data[:strStartDate]
    params[:strDob] = data[:strDob]
    params[:strMobilePhone] = data[:strMobilePhone]
    params[:strEmergencyAddressContactName] = data[:strEmergencyAddressContactName]
    params[:strEmergencyAddressPhone] = data[:strEmergencyAddressPhone]

    params[:intCompanyId] = data[:intCompanyId]
    params[:intGender] = data[:intGender]

    params[:strStreet] = data[:strStreet]
    params[:strState] = data[:strState]
    params[:strCity] = data[:strCity]
    params[:strPostCode] = data[:strPostCode]
    params[:strCountryCode] = data[:strCountryCode]

    params[:fltAnnualSalary] = data[:fltAnnualSalary]
    params[:fltWeekdayRate] = data[:fltWeekdayRate]
    params[:fltSaturdayRate] = data[:fltSaturdayRate]
    params[:fltSundayRate] = data[:fltSundayRate]
    params[:fltPublicHolidayRate] = data[:fltPublicHolidayRate]

    params[:blnSendInvite] = should_send_invite && 1 || 0

    params
  end

  def build_update_profile_params(data)
    params = {}

    params[:strFirstName] = data[:strFirstName] if data.key?(:strFirstName)
    params[:strLastName] = data[:strLastName] if data.key?(:strLastName)
    params[:strEmail] = data[:strEmail] if data.key?(:strEmail)
    params[:strStartDate] = data[:strStartDate] if data.key?(:strStartDate)
    params[:strDob] = data[:strDob] if data.key?(:strDob)
    params[:strMobilePhone] = data[:strMobilePhone] if data.key?(:strMobilePhone)
    params[:strEmergencyAddressContactName] = data[:strEmergencyAddressContactName] if data.key?(:strEmergencyAddressContactName)
    params[:strEmergencyAddressPhone] = data[:strEmergencyAddressPhone] if data.key?(:strEmergencyAddressPhone)
 
    params[:intCompanyId] = data[:intCompanyId] if data.key?(:intCompanyId)
    params[:intGender] = data[:intGender] if data.key?(:intGender)

    params[:strStreet] = data[:strStreet] if data.key?(:strStreet)
    params[:strState] = data[:strState] if data.key?(:strState)
    params[:strCity] = data[:strCity] if data.key?(:strCity)
    params[:strPostCode] = data[:strPostCode] if data.key?(:strPostCode)
    params[:strCountryCode] = data[:strCountryCode] if data.key?(:strCountryCode)

    params[:fltAnnualSalary] = data[:fltAnnualSalary] if data.key?(:fltAnnualSalary)
    params[:fltWeekdayRate] = data[:fltWeekdayRate] if data.key?(:fltWeekdayRate)
    params[:fltSaturdayRate] = data[:fltSaturdayRate] if data.key?(:fltSaturdayRate)
    params[:fltSundayRate] = data[:fltSundayRate] if data.key?(:fltSundayRate)
    params[:fltPublicHolidayRate] = data[:fltPublicHolidayRate] if data.key?(:fltPublicHolidayRate)

    params
  end

  def build_rehire_profile_params(data, should_send_invite = false)
    build_create_profile_params(data, should_send_invite)
  end
end