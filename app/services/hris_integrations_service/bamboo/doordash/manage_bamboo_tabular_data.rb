class HrisIntegrationsService::Bamboo::Doordash::ManageBambooTabularData < HrisIntegrationsService::Bamboo::ManageBambooTabularData
  attr_reader :user, :compensation_custom_fields, :equity_custom_fields, :req_id_custom_fields, :job_family_custom_fields, :commission_custom_fields, :job_info_custom_fields, :physical_office_location_custom_fields, :amount_type_field_value, :employment_status_custom_fields, :new_hire_grant_custom_fields

  def initialize(user)
    super(user)
    @amount_type_field_value = HrisIntegrationsService::Bamboo::AmountFieldValueMapping.new user
    @compensation_custom_fields = {
      'compensation date' => 'startDate',
      'pay rate (annual)' => 'annualRate',
      'pay rate (hourly)' => 'hourlyRate',
      'pay type' => 'type',
      'compensation change reason' => 'reason',
      'pay rate per' => 'paidPer',
      'pay schedule' => 'paySchedule'
    }

    @commission_custom_fields = {
      'commission amount' => 'amount',
      'commission comment' => 'comment',
      'commission date' => 'date'
    }
    @equity_custom_fields = {
      'equity issue date' => 'customIssueDate',
      '# of shares' => 'custom#ofShares',
      'equity comment' => 'customComment',
      'equity value' => 'customEquityValue1'
    }
    @job_family_custom_fields = {
      'job family effective date' => 'customEffectiveDate',
      'job family' => 'customJobFamily',
      'job level' => 'customJobLevel'
    }
    @req_id_custom_fields = {
      'req id effective date' => 'customEffectiveDate1',
      'req id #' => 'customReqID#',
      'req id change reason' => 'customChangeReason'
    }
    @physical_office_location_custom_fields = {
      'physical office location effective date' => 'customEffectiveDate3',
      'physical work location' => 'customPhysicalOfficeLocation',
      'physical work location comment' => 'customComment3'
    }
    @new_hire_grant_custom_fields ={
      'new hire related start date' => 'customDate',
      'sign on bonus' => 'signOnBonus',
      'relocation bonus' => 'relocationBonus',
      'new hire related payments reason' => 'customReason'
    }
    @employment_status_custom_fields = {
      'employment status effective date' => 'date',
      'employment status' => 'employmentStatus',
      'employment status comment' => 'comment'
    }
    @emergency_custom_fields = {
      'emergency contact name' => 'name',
      'emergency contact relationship' => 'relationship',
      'emergency contact mobile number' => 'mobilePhone',
      'emergency contact email' => 'email'
    }
  end

  def update_tabular_data
    update_job_information
    update_emergency_contact
    update_compensation
    update_commission
    update_equity
    update_job_family
    update_req_id
    update_physical_office_location
    update_new_hire_grant
    update_employment_status
  end

  def update_selected_tabular_data(field_name)
    field_name = field_name.downcase
    super(field_name)

    if compensation_custom_fields.include? field_name
      update_compensation
    elsif emergency_custom_fields.include? field_name
      update_emergency_contact
    elsif commission_custom_fields.include? field_name
      update_commission
    elsif equity_custom_fields.include? field_name
      update_equity
    elsif job_family_custom_fields.include? field_name
     	update_job_family
    elsif req_id_custom_fields.include? field_name
     	update_req_id
    elsif physical_office_location_custom_fields.include? field_name    
      update_physical_office_location
    elsif new_hire_grant_custom_fields.include? field_name
      update_new_hire_grant
    elsif employment_status_custom_fields.include? field_name
      update_employment_status
    end
  end

  def compensation_params
    paidPer = user.get_custom_field_value_text(compensation_custom_fields.key('paidPer'))
    if paidPer.present?
      if paidPer.downcase == 'year'
        rate = amount_type_field_value.fetch_custom_field_value(compensation_custom_fields.key('annualRate')) 
      elsif paidPer.downcase == 'hour'
        rate = amount_type_field_value.fetch_custom_field_value(compensation_custom_fields.key('hourlyRate'))
      end
    else
      rate = amount_type_field_value.fetch_custom_field_value(compensation_custom_fields.key('annualRate')) || amount_type_field_value.fetch_custom_field_value(compensation_custom_fields.key('hourlyRate'))
    end

    type = user.get_custom_field_value_text(compensation_custom_fields.key('type'))
    reason = user.get_custom_field_value_text(compensation_custom_fields.key('reason'))
    paySchedule = user.get_custom_field_value_text(compensation_custom_fields.key('paySchedule'))
    startDate = user.get_custom_field_value_text(compensation_custom_fields.key('startDate')) || user.start_date.try(:to_s)

    params = nil
    if rate.present? || type.present? || paidPer.present? || paySchedule.present? || reason.present?
      params = "<row>
        <field id='startDate'>#{startDate}</field>
        <field id='rate'>#{rate}</field>
        <field id='type'>#{type}</field>
        <field id='reason'>#{reason}</field>
        <field id='paidPer'>#{paidPer}</field>
        <field id='paySchedule'>#{paySchedule}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def equity_params
    customIssueDate = user.get_custom_field_value_text(equity_custom_fields.key('customIssueDate')) || user.start_date.to_s
    customofShares = user.get_custom_field_value_text(equity_custom_fields.key('custom#ofShares'))
    customComment = user.get_custom_field_value_text(equity_custom_fields.key('customComment'))
    customEquityValue1 = amount_type_field_value.fetch_custom_field_value(equity_custom_fields.key('customEquityValue1'))

    return "<row>
      <field id='customIssueDate'>#{customIssueDate}</field>
      <field id='custom#ofShares'>#{customofShares}</field>
      <field id='customComment'>#{customComment}</field>
      <field id='customEquityValue1'>#{customEquityValue1}</field>
    </row>".gsub('&', '&amp;')
  end

  def req_id_params
    customEffectiveDate1 = user.get_custom_field_value_text(req_id_custom_fields.key('customEffectiveDate1')) || user.start_date.to_s
    customReqID = user.get_custom_field_value_text(req_id_custom_fields.key('customReqID#')).to_s
    customChangeReason = user.get_custom_field_value_text(req_id_custom_fields.key('customChangeReason')).to_s

    return "<row>
      <field id='customEffectiveDate1'>#{customEffectiveDate1}</field>
      <field id='customReqID#'>#{customReqID}</field>
      <field id='customChangeReason'>#{customChangeReason}</field>
    </row>".gsub('&', '&amp;')
  end

  def job_family_params
    customEffectiveDate = user.get_custom_field_value_text(job_family_custom_fields.key('customEffectiveDate')) || user.start_date.to_s
    customJobFamily = user.get_custom_field_value_text(job_family_custom_fields.key('customJobFamily'))
    customJobLevel = user.get_custom_field_value_text(job_family_custom_fields.key('customJobLevel'))

    return "<row>
      <field id='customEffectiveDate'>#{customEffectiveDate}</field>
      <field id='customJobFamily'>#{customJobFamily}</field>
      <field id='customJobLevel'>#{customJobLevel}</field>
    </row>".gsub('&', '&amp;')
  end

  def commission_params
    date = user.get_custom_field_value_text(commission_custom_fields.key('date')) || user.start_date.try(:to_s)
    amount = user.get_custom_field_value_text(commission_custom_fields.key('amount'))
    comment = user.get_custom_field_value_text(commission_custom_fields.key('comment'))

    return "<row>
      <field id='date'>#{date}</field>
      <field id='amount'>#{amount}</field>
      <field id='comment'>#{comment}</field>
    </row>".gsub('&', '&amp;')
  end

  def physical_office_location_params
    customEffectiveDate3 = user.get_custom_field_value_text(physical_office_location_custom_fields.key('customEffectiveDate3')) || user.start_date.try(:to_s)
    customPhysicalOfficeLocation = user.get_custom_field_value_text(physical_office_location_custom_fields.key('customPhysicalOfficeLocation'))
    customComment3 = user.get_custom_field_value_text(physical_office_location_custom_fields.key('customComment3'))

    if customPhysicalOfficeLocation.present? || customComment3.present?
      return "<row>
        <field id='customEffectiveDate3'>#{customEffectiveDate3}</field>
        <field id='customPhysicalOfficeLocation'>#{customPhysicalOfficeLocation}</field>
        <field id='customComment3'>#{customComment3}</field>
      </row>".gsub('&', '&amp;')
    end
  end

  def employment_status_params
    date = user.get_custom_field_value_text(employment_status_custom_fields.key('date')) || user.start_date.try(:to_s)
    employmentStatus = user.employee_type rescue nil
    comment = user.get_custom_field_value_text(employment_status_custom_fields.key('comment'))
    
    return "<row>
      <field id='date'>#{date}</field>
      <field id='employmentStatus'>#{employmentStatus}</field>
      <field id='comment'>#{comment}</field>
    </row>".gsub('&', '&amp;')
  end

  def new_hire_grant_params
    customAmount = amount_type_field_value.fetch_custom_field_value(new_hire_grant_custom_fields.key('signOnBonus'), true) || amount_type_field_value.fetch_custom_field_value(new_hire_grant_custom_fields.key('relocationBonus'), true)

    if customAmount
      customDate = user.get_custom_field_value_text(new_hire_grant_custom_fields.key('customDate')) || user.start_date.to_s
      customReason = user.get_custom_field_value_text(new_hire_grant_custom_fields.key('customReason'))
    
      return "<row>
        <field id='customDate'>#{customDate}</field>
        <field id='customAmount'>#{customAmount}</field>
        <field id='customReason'>#{customReason}</field>
      </row>".gsub('&', '&amp;')
    end  
  end

  def emergency_contact_params
    name = user.get_custom_field_value_text(emergency_custom_fields.key('name'))
    relationship = user.get_custom_field_value_text(emergency_custom_fields.key('relationship'))
    mobilePhone = user.get_custom_field_value_text(emergency_custom_fields.key('mobilePhone'))
    email = user.get_custom_field_value_text(emergency_custom_fields.key('email'))

    return "<row>
      <field id='name'>#{name}</field>
      <field id='relationship'>#{relationship}</field>
      <field id='mobilePhone'>#{mobilePhone}</field>
      <field id='email'>#{email}</field>
    </row>".gsub('&', '&amp;')
  end

  private

  def update_new_hire_grant
    params = new_hire_grant_params
    if params.present?
      new_hire_grant = HrisIntegrationsService::Bamboo::Doordash::NewHireGrant.new user.company
      new_hire_grant.create_or_update("#{user.id}: Create/Update NewHireGrant In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_compensation
    params = compensation_params
    if params.present?
      compensation = HrisIntegrationsService::Bamboo::Compensation.new(user.company)
      compensation.create_or_update("#{user.id}: Create/Update Compensation In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_equity
    params = equity_params
    if params.present?
      equity = HrisIntegrationsService::Bamboo::Equity.new(user.company)
      equity.create_or_update_custom("#{user.id}: Create/Update Equity In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_req_id
    params = req_id_params
    if params.present?
      reqID = HrisIntegrationsService::Bamboo::ReqID.new(user.company)
      reqID.create_or_update_custom("#{user.id}: Create/Update Equity In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_job_family
    params = job_family_params
    if params.present?
      jobFamily = HrisIntegrationsService::Bamboo::JobFamily.new(user.company)
      jobFamily.create_or_update_custom("#{user.id}: Create/Update JobFamily In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_commission
    params = commission_params
    if params.present?
      commission = HrisIntegrationsService::Bamboo::Commission.new(user.company)
      commission.create_or_update("#{user.id}: Create/Update Commission In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end
  #:nocov:
  def update_job_info
    params = job_info_params
    if params.present?
      jobInfo = HrisIntegrationsService::Bamboo::JobInformation.new(user.company)
      jobInfo.create_or_update("#{user.id}: Create/Update Job Information In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end
  #:nocov:

  def update_physical_office_location
    params = physical_office_location_params
    if params.present?
      officeLocation = HrisIntegrationsService::Bamboo::PhysicalOfficeLocation.new(user.company)
      officeLocation.create_or_update_custom("#{user.id}: Create/Update Physical Office Location In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_employment_status
    params = employment_status_params
    if params.present?
      employment_status = HrisIntegrationsService::Bamboo::EmploymentStatus.new(user.company)
      employment_status.create_or_update("#{user.id}: Create/Update Employment Status In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_emergency_contact
    params = emergency_contact_params
    emergency_contact = HrisIntegrationsService::Bamboo::EmergencyContact.new(user.company)
    emergency_contact.create_or_update("#{user.id}: Create/Update Emergency Contact In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
  end
end
