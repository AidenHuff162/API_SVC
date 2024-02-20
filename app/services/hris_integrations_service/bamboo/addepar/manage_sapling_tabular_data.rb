class HrisIntegrationsService::Bamboo::Addepar::ManageSaplingTabularData < HrisIntegrationsService::Bamboo::ManageSaplingTabularData

  def initialize(company)
    super(company)
    emergency_custom_fields.merge!({
      email: 'Emergency Contact Email Address',
      emergencyContactAddress: 'Emergency Contact Address'
    })

    emergency_sub_custom_fields.merge!({
      addressLine1: 'Line 1',
      addressLine2: 'Line 2',
      city: 'City',
      state: 'State',
      zipcode: 'Zip',
      country: 'Country'
    })

    immigration_custom_fields.merge!({
      index1: 'Country of citizenship',
      index2: 'Type of Visa (if applicable)',
      index3: 'Visa Expiration Date (If applicable)'
    })

    level_custom_fields.merge!({
      index1: 'Level',
      index2: 'Comp Band Code'
    })

    @bonus_cutom_fields.merge!({
      customBonusAmount: 'Bonus Amount',
      customBonusType: 'Bonus Type',
      customComments: 'Bonus Comments'
    })

    @compensation_custom_fields.merge!({
      startDate: 'Pay Rate Effective Date',
      rate: 'Pay Rate',
      type: 'Pay Type',
      paidPer: 'Pay Period',
      paySchedule: 'Pay Schedule',
      exempt: 'flsa code (exempt/non exempt)'
    })
  end

  def manage_custom_fields(user)
    super(user)
    update_compensation(user)
    update_bonus(user, 'customBonuses')
    update_immigration(user)
    update_level(user)
  end
end
