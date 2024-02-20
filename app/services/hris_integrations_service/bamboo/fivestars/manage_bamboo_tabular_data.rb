class HrisIntegrationsService::Bamboo::Fivestars::ManageBambooTabularData < HrisIntegrationsService::Bamboo::ManageBambooTabularData
  attr_reader :compensation_custom_fields, :federal_tax_withholding_custom_fields, :direct_deposit_custom_fields, :fivestars_employment_status_fields

  def initialize(user)
    super(user)
    @emergency_custom_fields.merge! ({
      'emergency contact address' => 'address',
      'emergency contact email' => 'email'
    })

    @employment_status_fields = []
    @fivestars_employment_status_fields = [ 'employment status' ]
    @compensation_custom_fields = {
      'pay rate effective date' => 'startDate',
      'pay rate (salary or per hr)' => 'rate',
      'pay type' => 'type',
      'pay per' => 'paidPer',
      'pay schedule' => 'paySchedule'
    }
    @federal_tax_withholding_custom_fields = {
      'w4: tax withholding allowance #' => 'customFederalTaxAllowance(5)',
      'w4: federal marital status' => 'customMaritalStatus(3)',
      'work state' => 'customWorkState'
    }
    @direct_deposit_custom_fields = {
      'direct deposit: routing number' => 'customRouting',
      'direct deposit: account number' => 'customAccountNumber',
      'direct deposit: bank type' => 'customType'
    }
  end

  def update_tabular_data
    update_emergency_contact
    update_job_information
    update_employment_status
    update_compensation
    update_direct_deposit
    update_federal_tax_withholding
  end

  def update_selected_tabular_data(field_name)
    super(field_name)
    if fivestars_employment_status_fields.include? field_name.try(:downcase)
      update_employment_status
    elsif compensation_custom_fields["#{field_name.try(:downcase)}"].present?
      update_compensation
    elsif federal_tax_withholding_custom_fields["#{field_name.try(:downcase)}"].present?
      update_federal_tax_withholding
    elsif direct_deposit_custom_fields["#{field_name.try(:downcase)}"].present?
      update_direct_deposit
    end
  end

  def employment_status_params
    employmentHistoryStatus = user.employee_type rescue nil

    params = nil
    if employmentHistoryStatus.present?
      params = "<row>
        <field id='date'>#{user.start_date.to_s}</field>
        <field id='employmentStatus'>#{employmentHistoryStatus}</field>
      </row>"
    end

    params
  end

  def compensation_params
    rate = user.get_custom_field_value_text(compensation_custom_fields.key('rate'))
    type = user.get_custom_field_value_text(compensation_custom_fields.key('type'))
    paidPer = user.get_custom_field_value_text(compensation_custom_fields.key('paidPer'))
    paySchedule = user.get_custom_field_value_text(compensation_custom_fields.key('paySchedule'))

    params = nil
    if rate.present? || type.present? || paidPer.present? || paySchedule.present?
      params = "<row>
        <field id='startDate'>#{user.start_date.try(:to_s)}</field>
        <field id='rate'>#{rate}</field>
        <field id='type'>#{type}</field>
        <field id='paidPer'>#{paidPer}</field>
        <field id='paySchedule'>#{paySchedule}</field>
      </row>"
    end

    params
  end

  def federal_tax_withholding_params
    customFederalTaxAllowance = user.get_custom_field_value_text(federal_tax_withholding_custom_fields.key('customFederalTaxAllowance(5)'))
    customMaritalStatus = user.get_custom_field_value_text(federal_tax_withholding_custom_fields.key('customMaritalStatus(3)'))
    customWorkState = user.get_custom_field_value_text(federal_tax_withholding_custom_fields.key('customWorkState'))

    params = nil
    if customFederalTaxAllowance.present? || customMaritalStatus.present? || customWorkState.present?
      params = "<row>
        <field id='customFederalTaxAllowance(5)'>#{customFederalTaxAllowance}</field>
        <field id='customMaritalStatus(3)'>#{customMaritalStatus}</field>
        <field id='customWorkState'>#{customWorkState}</field>
      </row>"
    end
    params
  end

  def direct_deposit_params
    customRouting = user.get_custom_field_value_text(direct_deposit_custom_fields.key('customRouting'))
    customAccountNumber = user.get_custom_field_value_text(direct_deposit_custom_fields.key('customAccountNumber'))
    customType = user.get_custom_field_value_text(direct_deposit_custom_fields.key('customType'))

    params = nil
    if customRouting.present? || customAccountNumber.present? || customType.present?
      params = "<row>
        <field id='customRouting'>#{customRouting}</field>
        <field id='customAccountNumber'>#{customAccountNumber}</field>
        <field id='customType'>#{customType}</field>
      </row>"
    end
    params
  end

  private

  def update_employment_status
    params = employment_status_params
    if params.present?
      employment_status = HrisIntegrationsService::Bamboo::EmploymentStatus.new(user.company)
      employment_status.create_or_update("#{user.id}: Create/Update Employment Status In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_compensation
    params = compensation_params
    if params.present?
      compensation = HrisIntegrationsService::Bamboo::Compensation.new(user.company)
      compensation.create_or_update("#{user.id}: Create/Update Compensation In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_federal_tax_withholding
    params = federal_tax_withholding_params
    if params.present?
      federal_tax_withholding = HrisIntegrationsService::Bamboo::FederalTaxWithholding.new(user.company)
      federal_tax_withholding.create_or_update("#{user.id}: Create/Update Federal Tax Withodling In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_direct_deposit
    params = direct_deposit_params
    if params.present?
      direct_deposit = HrisIntegrationsService::Bamboo::DirectDeposit.new(user.company)
      direct_deposit.create_or_update("#{user.id}: Create/Update Direct Deposit In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end
end
