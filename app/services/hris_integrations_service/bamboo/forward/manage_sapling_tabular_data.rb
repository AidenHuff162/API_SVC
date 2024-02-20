class HrisIntegrationsService::Bamboo::Forward::ManageSaplingTabularData < HrisIntegrationsService::Bamboo::ManageSaplingTabularData
  attr_reader :employment_status_custom_fields, :secondary_compensation_custom_fields, :stock_awards_custom_fields, :visa_information_custom_fields, :commission_plan_custom_fields, :bonus_payments_custom_fields, :custom_level_custom_fields, :bonus_plan_custom_fields
  
  def initialize(company)
    super(company)
    @job_info_custom_fields = {
      date: 'job information: date'
    }
    @employment_status_custom_fields = {
      terminationTypeId: 'termination type', 
      terminationReasonId: 'termination reason',
      terminationRehireId: 'eligible for re-hire'
    }
    @compensation_custom_fields.merge!({
      startDate: 'compensation: date',
      rate: 'Pay Rate',
      type: 'Pay Type',
      paidPer: 'Paid Per',
      paySchedule: 'Pay Schedule',
      exempt: 'Overtime Status',
      comment: 'Compensation Comments',
      reason: 'Compensation Change Reason',
    })
   @secondary_compensation_custom_fields = {
      customPayRate: 'secondary compensation - pay rate',
      customPaySchedule: 'secondary compensation - pay schedule',
      customPayType: 'Secondary Compensation - Pay Type'
    }
    @stock_awards_custom_fields = {
      customCertificateNumber: 'certificate number',
      customVestTerms: 'vest terms',
      customVestCommencementDate: 'vest commencement date',
      customNumberofShares: 'number of shares',
      customOriginalCertificateNumber: 'original certificate number'
    }
     @visa_information_custom_fields = {
      customVisaExpiration: 'visa expiration',
      customVisaType: 'visa type',
      customVisaNumber: 'visa number'
    }
    @commission_plan_custom_fields = {
      customTarget: 'target',
      customTargetType: 'target type',
      customCommissionPlanID1: 'commission plan - commission plan id',
      customEntity1: 'commission plan - entity'
    }
    @bonus_payments_custom_fields = {
      customCommissionPlanID: 'bonus payments - commission plan id',
      customEntitiy: 'bonus payments - entity'
    }
    @custom_level_custom_fields = {
      customLevel: 'level'
    }
    @bonus_plan_custom_fields = {
      customEntity: 'bonus plan - entity'
    }
  end

  def manage_custom_fields(user)
    super(user)
    update_job_information(user)
    update_employment_status(user)
    update_compensation(user)
    update_secondary_compensation(user)
    update_stock_awards(user)
    update_visa_information(user)
    update_commission_plan(user)
    update_bonus_payments(user)
    update_custom_level(user)
    update_bonus_plan(user)
  end

  private
  def update_job_information(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::JobInformation.new(company).fetch(user.bamboo_id).try(:last) || {}
      CustomFieldValue.set_custom_field_value(user, job_info_custom_fields[:date], bamboo_data['date']) if bamboo_data.present?
      log("#{user.id}: Update Job Info In Sapling (#{user.bamboo_id}) - Success",  {request: "GET USERS/#{user.bamboo_id}/jobInformation"}, {response: job_info_custom_fields, bamboo: bamboo_data}, 200)
    rescue  Exception => exception
      log("#{user.id}: Update Job Info In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/jobInformation"}, {response: job_info_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_employment_status(user)
    begin
      bamboo_data = ::HrisIntegrationsService::Bamboo::EmploymentStatus.new(company).fetch(user.bamboo_id).try(:last) || {}
      user.termination_type = bamboo_data['terminationTypeId'] if bamboo_data.present?
      user.eligible_for_rehire = bamboo_data['terminationRehireId'] if bamboo_data.present?
      user.save!
      CustomFieldValue.set_custom_field_value(user, employment_status_custom_fields[:terminationReasonId], bamboo_data['terminationReasonId']) if bamboo_data.present?

      log("#{user.id}: Update Employement status In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/employmentStatus"}, {response: employment_status_custom_fields, bamboo: bamboo_data}, 200)
    rescue  Exception => exception
      log("#{user.id}: Update Employement status In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/employmentStatus"}, {response: employment_status_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_compensation(user)
    begin
    bamboo_data = HrisIntegrationsService::Bamboo::Compensation.new(company).fetch(user.bamboo_id).try(:last) || {}
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:startDate], bamboo_data['startDate'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:rate], bamboo_data['rate']['currency'], 'Currency Type', false)
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:rate], bamboo_data['rate']['value'], 'Currency Value', false)
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:type], bamboo_data['type'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:paidPer], bamboo_data['paidPer'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:paySchedule], bamboo_data['paySchedule'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:reason], bamboo_data['reason'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:exempt], bamboo_data['exempt'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:comment], bamboo_data['comment'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:paidPer], bamboo_data['paidPer'])
      end
      log("#{user.id}: Update Compensation Information In Sapling (#{user.bamboo_id}) - Success", {bamboo: "GET USERS/#{user.bamboo_id}/compensation"}, {response: compensation_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Compensation Information In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/compensation"}, {response: compensation_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_secondary_compensation(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Forward::SecondaryCompensation.new(company).fetch(user.bamboo_id).try(:last).try(:last) || {}
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, secondary_compensation_custom_fields[:customPayRate], bamboo_data['customPayRate'])
        CustomFieldValue.set_custom_field_value(user, secondary_compensation_custom_fields[:customPaySchedule], bamboo_data['customPaySchedule'])
        CustomFieldValue.set_custom_field_value(user, secondary_compensation_custom_fields[:customPayType], bamboo_data['customPayType'])
      end
      log("#{user.id}: Update Secondary Compensation Information In Sapling (#{user.bamboo_id}) - Success", {bamboo: "GET USERS/#{user.bamboo_id}/customSecondaryCompensation"}, {response: secondary_compensation_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Secondary Compensation Information In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/customSecondaryCompensation"}, {response: secondary_compensation_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_stock_awards(user)
   begin
      bamboo_data = HrisIntegrationsService::Bamboo::Forward::CustomStockAwards.new(company).fetch(user.bamboo_id).try(:last).try(:last) || {}
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, stock_awards_custom_fields[:customCertificateNumber], bamboo_data['customCertificateNumber'])
        CustomFieldValue.set_custom_field_value(user, stock_awards_custom_fields[:customVestTerms], bamboo_data['customVestTerms'])
        CustomFieldValue.set_custom_field_value(user, stock_awards_custom_fields[:customVestCommencementDate], bamboo_data['customVestCommencementDate'])
        CustomFieldValue.set_custom_field_value(user, stock_awards_custom_fields[:customNumberofShares], bamboo_data['customNumberofShares'])
        CustomFieldValue.set_custom_field_value(user, stock_awards_custom_fields[:customOriginalCertificateNumber], bamboo_data['customOriginalCertificateNumber'])
      end
      log("#{user.id}: Update Stock Awards In Sapling (#{user.bamboo_id}) - Success", {bamboo: "GET USERS/#{user.bamboo_id}/customStockAwards"}, {response: stock_awards_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Stock Awards In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/customStockAwards"}, {response: stock_awards_custom_fields, bamboo: exception.message}, 500)
    end
  end
  def update_visa_information(user)
   begin
      bamboo_data = HrisIntegrationsService::Bamboo::Forward::VisaInformation.new(company).fetch(user.bamboo_id).try(:last).try(:last) || {}
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, visa_information_custom_fields[:customVisaExpiration], bamboo_data['customVisaExpiration'])
        CustomFieldValue.set_custom_field_value(user, visa_information_custom_fields[:customVisaType], bamboo_data['customVisaType'])
        CustomFieldValue.set_custom_field_value(user, visa_information_custom_fields[:customVisaNumber], bamboo_data['customVisaNumber'])
      end
      log("#{user.id}: Update Visa Information In Sapling (#{user.bamboo_id}) - Success", {bamboo: "GET USERS/#{user.bamboo_id}/visaInfo"}, {response: visa_information_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Visa Information In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/visaInfo"}, {response: visa_information_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_commission_plan(user)
   begin
      bamboo_data = HrisIntegrationsService::Bamboo::Forward::CommissionPlan.new(company).fetch(user.bamboo_id).try(:last).try(:last) || {}
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, commission_plan_custom_fields[:customTarget], bamboo_data['customTarget'])
        CustomFieldValue.set_custom_field_value(user, commission_plan_custom_fields[:customTargetType], bamboo_data['customTargetType'])
        CustomFieldValue.set_custom_field_value(user, commission_plan_custom_fields[:customCommissionPlanID1], bamboo_data['customCommissionPlanID1'])
        CustomFieldValue.set_custom_field_value(user, commission_plan_custom_fields[:customEntity1], bamboo_data['customEntity1'])
      end
      log("#{user.id}: Update Commission Plan In Sapling (#{user.bamboo_id}) - Success", {bamboo: "GET USERS/#{user.bamboo_id}/commissionPlan"}, {response: commission_plan_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Commission Plan In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/commissionPlan"}, {response: commission_plan_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_bonus_payments(user)
   begin
      bamboo_data = HrisIntegrationsService::Bamboo::Forward::BonusPayment.new(company).fetch(user.bamboo_id).try(:last).try(:last) || {}
      CustomFieldValue.set_custom_field_value(user, bonus_payments_custom_fields[:customTarget], bamboo_data['customTarget']) if bamboo_data.present?
      CustomFieldValue.set_custom_field_value(user, bonus_payments_custom_fields[:customTargetType], bamboo_data['customTargetType']) if bamboo_data.present?
      log("#{user.id}: Update Bonus Payments In Sapling (#{user.bamboo_id}) - Success", {bamboo: "GET USERS/#{user.bamboo_id}/bonusPayments"}, {response: bonus_payments_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Bonus Payments In Sapling (#{user.bamboo_id}) - Failure",{request: "GET USERS/#{user.bamboo_id}/bonusPayments"}, {response: bonus_payments_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_custom_level(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Forward::CustomLevel.new(company).fetch(user.bamboo_id).try(:last).try(:last) || {}
      CustomFieldValue.set_custom_field_value(user, custom_level_custom_fields[:customLevel], bamboo_data['customLevel']) if bamboo_data.present?
      log("#{user.id}: Update Custom Level In Sapling (#{user.bamboo_id}) - Success", {bamboo: "GET USERS/#{user.bamboo_id}/customLevel"}, {response: custom_level_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Custom Level In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/customLevel"}, {response: custom_level_custom_fields, bamboo: exception.message}, 500)
    end
  end
  
  def update_bonus_plan(user)
  begin
      bamboo_data = HrisIntegrationsService::Bamboo::Forward::BonusPlan.new(company).fetch(user.bamboo_id).try(:last).try(:last) || {}
      CustomFieldValue.set_custom_field_value(user, bonus_plan_custom_fields[:customEntity], bamboo_data['customEntity']) if bamboo_data.present?
      log("#{user.id}: Update Bonus Plan In Sapling (#{user.bamboo_id}) - Success",  {bamboo: "GET USERS/#{user.bamboo_id}/bonusPlan"}, {response: bonus_payments_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Bonus Plan In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/bonusPlan"}, {response: bonus_payments_custom_fields, bamboo: exception.message}, 500)
    end
  end
    
end
