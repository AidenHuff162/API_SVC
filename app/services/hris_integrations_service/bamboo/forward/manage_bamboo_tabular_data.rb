class HrisIntegrationsService::Bamboo::Forward::ManageBambooTabularData < HrisIntegrationsService::Bamboo::ManageBambooTabularData
  attr_reader :compensation_custom_fields, :stock_awards_custom_fields, :visa_information_custom_fields, :secondary_compensation_custom_fields, :commission_plan_custom_fields, :bonus_payment_custom_fields, :custom_level_custom_fields, :bonus_plan_custom_fields, :employment_status_custom_fields, :job_information_custom_fields

  def initialize(user)
    super(user)
    @employment_status_fields = []
    @employment_status_custom_fields = {
      'termination type' => 'terminationTypeId', 
      'termination reason' => 'terminationReasonId',
      'eligible for re-hire' => 'terminationRehireId'
    }
    @job_information_fields = []
    @job_information_custom_fields = {
     'job information: date' => 'date'
    }
    @compensation_custom_fields = {
      'compensation: date' => 'startDate',
      'compensation change reason' => 'reason',
      'compensation comments' => 'comment',
      'overtime status' => 'exempt',
      'pay rate' => 'rate',
      'pay schedule' => 'paySchedule',
      'pay type' => 'type',
      'paid per' => 'paidPer'
    }
     @secondary_compensation_custom_fields = {
      'secondary compensation - pay rate' => 'customPayRate',
      'secondary compensation - pay schedule' => 'customPaySchedule',
      'Secondary Compensation - Pay Type' => 'customPayType'
    }
    @stock_awards_custom_fields = {
      'certificate number' => 'customCertificateNumber',
      'vest terms' => 'customVestTerms',
      'vest commencement date' => 'customVestCommencementDate',
      'number of shares' => 'customNumberofShares',
      'original certificate number' => 'customOriginalCertificateNumber'
    }
    @visa_information_custom_fields = {
      'visa expiration' => 'customVisaExpiration',
      'visa type' => 'customVisaType',
      'visa number' => 'customVisaNumber'
    }
    @commission_plan_custom_fields = {
      'target' => 'customTarget',
      'target type' => 'customTargetType',
      'commission plan - commission plan id' => 'customCommissionPlanID1',
      'commission plan - entity' => 'customEntity1'
    }
    @bonus_payment_custom_fields = {
      'bonus payments - commission plan id' => 'customCommissionPlanID',
      'bonus payments - entity' => 'customEntitiy'
    }
    @custom_level_custom_fields = {
      'level' => 'customLevel'
    }
    @bonus_plan_custom_fields = {
      'bonus plan - entity' => 'customEntity'
    }
  end

  def update_tabular_data
    update_compensation
    update_secondary_compensation
    update_custom_stock_awards
    update_visa_information
    update_commission_plan
    update_bonus_payment
    update_custom_level
    update_bonus_plan
    update_employment_status
    update_job_information
  end

  def update_selected_tabular_data(field_name)
    super(field_name)
    if compensation_custom_fields["#{field_name.try(:downcase)}"].present?
      update_compensation
    elsif secondary_compensation_custom_fields["#{field_name.try(:downcase)}"].present?
      update_secondary_compensation true
    elsif stock_awards_custom_fields["#{field_name.try(:downcase)}"].present?
      update_custom_stock_awards
    elsif visa_information_custom_fields["#{field_name.try(:downcase)}"].present?
      update_visa_information
    elsif commission_plan_custom_fields["#{field_name.try(:downcase)}"].present?
      update_commission_plan true
    elsif bonus_payment_custom_fields["#{field_name.try(:downcase)}"].present?
      update_bonus_payment true
    elsif custom_level_custom_fields["#{field_name.try(:downcase)}"].present?
      update_custom_level true
    elsif bonus_plan_custom_fields["#{field_name.try(:downcase)}"].present?
      update_bonus_plan true
    elsif employment_status_custom_fields["#{field_name.try(:downcase)}"].present?
      update_employment_status true
    elsif job_information_custom_fields["#{field_name.try(:downcase)}"].present?
      update_job_information
    end

  end

  def compensation_params
    startDate = user.get_custom_field_value_text(compensation_custom_fields.key('startDate'))
    reason = user.get_custom_field_value_text(compensation_custom_fields.key('reason'))
    comment = user.get_custom_field_value_text(compensation_custom_fields.key('comment'))
    exempt = user.get_custom_field_value_text(compensation_custom_fields.key('exempt'))
    rate = user.get_custom_field_value_text(compensation_custom_fields.key('rate'))
    paySchedule = user.get_custom_field_value_text(compensation_custom_fields.key('paySchedule'))
    paidPer = user.get_custom_field_value_text(compensation_custom_fields.key('paidPer'))
    type = user.get_custom_field_value_text(compensation_custom_fields.key('type'))


    params = nil
    if reason.present? || comment.present? || exempt.present? || rate.present? || paySchedule.present? || type.present?

      params = "<row>
        <field id='startDate'>#{startDate}</field>
        <field id='type'>#{type}</field>
        <field id='rate'>#{rate}</field>
        <field id='exempt'>#{exempt}</field>
        <field id='reason'>#{reason}</field>
        <field id='comment'>#{comment}</field>
        <field id='paidPer'>#{paidPer}</field>
        <field id='paySchedule'>#{paySchedule}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def secondary_compensation_params can_send_current_date
    customPayRate = user.get_custom_field_value_text(secondary_compensation_custom_fields.key('customPayRate'))
    customPaySchedule = user.get_custom_field_value_text(secondary_compensation_custom_fields.key('customPaySchedule'))
    customPayType = user.get_custom_field_value_text(secondary_compensation_custom_fields.key('customPayType'))
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s

    params = nil
    if customPayRate.present? || customPaySchedule.present? || customPayType.present?
      params = "<row>
        <field id='customEffectiveDate3'>#{date}</field>
        <field id='customPayRate'>#{customPayRate}</field>
        <field id='customPaySchedule'>#{customPaySchedule}</field>
        <field id='customPayType'>#{customPayType}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def stock_awards_params
    customCertificateNumber = user.get_custom_field_value_text(stock_awards_custom_fields.key('customCertificateNumber'))
    customVestTerms = user.get_custom_field_value_text(stock_awards_custom_fields.key('customVestTerms'))
    customVestCommencementDate = user.get_custom_field_value_text(stock_awards_custom_fields.key('customVestCommencementDate'))
    customNumberofShares = user.get_custom_field_value_text(stock_awards_custom_fields.key('customNumberofShares'))
    customOriginalCertificateNumber = user.get_custom_field_value_text(stock_awards_custom_fields.key('customOriginalCertificateNumber'))
    
    params = nil
    if customCertificateNumber.present? || customVestTerms.present? || customVestCommencementDate.present? || customNumberofShares.present? || customOriginalCertificateNumber.present? 
      params = "<row>
        <field id='customNumberofShares'>#{customNumberofShares}</field>
        <field id='customVestCommencementDate'>#{customVestCommencementDate}</field>
        <field id='customVestTerms'>#{customVestTerms}</field>
        <field id='customCertificateNumber'>#{customCertificateNumber}</field>
        <field id='customOriginalCertificateNumber'>#{customOriginalCertificateNumber}</field>
      </row>"
    end
    params
  end

  def visa_information_params
    customVisaExpiration = user.get_custom_field_value_text(visa_information_custom_fields.key('customVisaExpiration'))
    customVisaType = user.get_custom_field_value_text(visa_information_custom_fields.key('customVisaType'))
    customVisaNumber = user.get_custom_field_value_text(visa_information_custom_fields.key('customVisaNumber'))

    params = nil
    if customVisaExpiration.present? || customVisaType.present? || customVisaNumber.present?
      params = "<row>
        <field id='customVisaExpiration'>#{customVisaExpiration}</field>
        <field id='customVisaType'>#{customVisaType}</field>
        <field id='customVisaNumber'>#{customVisaNumber}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def commission_plan_params can_send_current_date
    customTarget = user.get_custom_field_value_text(commission_plan_custom_fields.key('customTarget'))
    customTargetType = user.get_custom_field_value_text(commission_plan_custom_fields.key('customTargetType'))
    customCommissionPlanID1 = user.get_custom_field_value_text(commission_plan_custom_fields.key('customCommissionPlanID1'))
    customEntity1 = user.get_custom_field_value_text(commission_plan_custom_fields.key('customEntity1'))
    
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s
    
    params = nil
    if customTarget.present? || customTargetType.present? || customCommissionPlanID1.present?
      params = "<row>
        <field id='customEffectiveDate2'>#{date}</field>
        <field id='customTarget'>#{customTarget}</field>
        <field id='customTargetType'>#{customTargetType}</field>
        <field id='customCommissionPlanID1'>#{customCommissionPlanID1}</field>
        <field id='customEntity1'>#{customEntity1}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def bonus_payment_params can_send_current_date
    customCommissionPlanID = user.get_custom_field_value_text(bonus_payment_custom_fields.key('customCommissionPlanID'))
    customEntitiy = user.get_custom_field_value_text(bonus_payment_custom_fields.key('customEntitiy'))
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s
    
    params = nil
    if customCommissionPlanID.present? || customEntitiy.present?
      params = "<row>
        <field id='customDate'>#{date}</field>
        <field id='customCommissionPlanID1'>#{customCommissionPlanID}</field>
        <field id='customEntitiy'>#{customEntitiy}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def custom_level_params can_send_current_date
    customLevel = user.get_custom_field_value_text(custom_level_custom_fields.key('customLevel'))
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s

    params = nil
    if customLevel.present?
      
      params = "<row>
        <field id='customEffectiveDate4'>#{date}</field>
        <field id='customLevel'>#{customLevel}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def bonus_plan_params can_send_current_date
    customEntity = user.get_custom_field_value_text(bonus_plan_custom_fields.key('customEntity'))
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s

    params = nil
    if customEntity.present?
      params = "<row>
        <field id='customEffectiveDate'>#{date}</field>
        <field id='customEntity'>#{customEntity}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end 

  def employement_status_params can_send_current_date
    terminationTypeId = user.termination_type
    terminationRehireId = user.eligible_for_rehire
    terminationReasonId = user.get_custom_field_value_text(employment_status_custom_fields.key('terminationReasonId'))

    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s
    
    params = nil
    if terminationTypeId.present? || terminationRehireId.present? || terminationReasonId.present?
      params = "<row>
        <field id='date'>#{date}</field>
        <field id='terminationTypeId'>#{terminationTypeId}</field>
        <field id='terminationRehireId'>#{terminationRehireId}</field>
        <field id='terminationReasonId'>#{terminationReasonId}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  def job_information_params
    date = user.get_custom_field_value_text(job_information_custom_fields.key('date'))
    
    params = nil
    if date.present?
      params = "<row>
        <field id='date'>#{date}</field>
      </row>".gsub('&', '&amp;')
    end

    params
  end

  private

  def update_compensation
    params = compensation_params
    if params.present?
      compensation = HrisIntegrationsService::Bamboo::Compensation.new(user.company)
      compensation.create_or_update("#{user.id}: Create/Update Compensation In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_secondary_compensation(can_send_current_date = false)
    params = secondary_compensation_params can_send_current_date
    if params.present?
      secondary_compensation = HrisIntegrationsService::Bamboo::Forward::SecondaryCompensation.new(user.company)
      secondary_compensation.create_or_update("#{user.id}: Create/Update Secondary Compensation In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_custom_stock_awards
    params = stock_awards_params
    if params.present?
      custom_stock_awards = HrisIntegrationsService::Bamboo::Forward::CustomStockAwards.new(user.company)
      custom_stock_awards.create_or_update("#{user.id}: Create/Update custom Stock Awards In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end


  def update_visa_information
    params = visa_information_params
    if params.present?
      visa_information = HrisIntegrationsService::Bamboo::Forward::VisaInformation.new(user.company)
      visa_information.create_or_update("#{user.id}: Create/Update Custom Visa Information In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_commission_plan(can_send_current_date = false)
    params = commission_plan_params can_send_current_date
    if params.present?
      commission_plan = HrisIntegrationsService::Bamboo::Forward::CommissionPlan.new(user.company)
      commission_plan.create_or_update("#{user.id}: Create/Update Custom Commission Plan In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_bonus_payment(can_send_current_date = false)
    params = bonus_payment_params can_send_current_date
    if params.present?
      bonus_payment = HrisIntegrationsService::Bamboo::Forward::BonusPayment.new(user.company)
      bonus_payment.create_or_update("#{user.id}: Create/Update Custom Bonus Payment In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_custom_level(can_send_current_date = false)
    params = custom_level_params can_send_current_date
    if params.present?
      custom_level = HrisIntegrationsService::Bamboo::Forward::CustomLevel.new(user.company)
      custom_level.create_or_update("#{user.id}: Create/Update Custom Level In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_bonus_plan(can_send_current_date = false)
    params = bonus_plan_params can_send_current_date
    if params.present?
      bonus_plan = HrisIntegrationsService::Bamboo::Forward::BonusPlan.new(user.company)
      bonus_plan.create_or_update("#{user.id}: Create/Update Bonus Plan In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_employment_status(can_send_current_date = false)
   params = employement_status_params can_send_current_date
    if params.present?
      employment_status = HrisIntegrationsService::Bamboo::EmploymentStatus.new(user.company)
      employment_status.create_or_update("#{user.id}: Create/Update Employment Status In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_job_information
    params = job_information_params
    job_information = HrisIntegrationsService::Bamboo::JobInformation.new(user.company)
    job_information.create_or_update("#{user.id}: Create/Update Job Information In Bamboo (#{user.bamboo_id})", user.bamboo_id, "<row>#{params}</row>")
  end
end
