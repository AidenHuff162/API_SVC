class HrisIntegrationsService::Deputy::ParamsMapper
  
  def build_parameter_mappings
    {
      strFirstName: 'first name',
      strLastName: 'last name',
      intCompanyId: 'location id',
      strStartDate: 'start date',
      strEmail: 'email',
      intGender: 'gender',
      strDob: 'date of birth',
      strMobilePhone: 'mobile phone number',
      strEmergencyAddressContactName: 'emergency contact name',
      strEmergencyAddressPhone: 'emergency contact number',
      homeAddress: 'home address',
      fltAnnualSalary: 'salary',
      fltWeekdayRate: 'weekday pay rate',
      fltSaturdayRate: 'saturday pay rate',
      fltSundayRate: 'sunday pay rate',
      fltPublicHolidayRate: 'holiday pay rate'
    }
  end
end