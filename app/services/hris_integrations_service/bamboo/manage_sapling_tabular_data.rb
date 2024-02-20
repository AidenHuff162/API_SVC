class HrisIntegrationsService::Bamboo::ManageSaplingTabularData
  attr_reader :company, :emergency_custom_fields, :emergency_sub_custom_fields, :countries, :immigration_custom_fields, :level_custom_fields, :bonus_cutom_fields, :compensation_custom_fields, :equity_custom_fields, :job_family_custom_fields, :req_Id_custom_fields, :commission_custom_fields, :job_info_custom_fields

  def initialize(company)
    @company = company
    @countries = Country.all.pluck(:name)
    @emergency_custom_fields = {
      name: 'Emergency Contact Name',
      workPhone: 'Emergency Contact Number',
      mobilePhone: 'Emergency Contact Number',
      homePhone: 'Emergency Contact Number',
      relationship: 'Emergency Contact Relationship'
    }
    @emergency_sub_custom_fields = {}
    @immigration_custom_fields = {}
    @level_custom_fields = {}
    @bonus_cutom_fields = {}
    @compensation_custom_fields = {}
    @equity_custom_fields = {}
    @req_Id_custom_fields = {}
    @job_family_custom_fields = {}
    @commission_custom_fields = {}
    @job_info_custom_fields = {}
  end

  def manage_custom_fields(user)
    update_emergency_contact(user)
  end

  def update_emergency_contact(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::EmergencyContact.new(company).fetch(user.bamboo_id).try(:last) || {}

      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:name], bamboo_data['name'])
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:workPhone], (bamboo_data['workPhone'] || bamboo_data['mobilePhone'] || bamboo_data['homePhone']))
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:relationship], bamboo_data['relationship'])
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:mobilePhone], bamboo_data['mobilePhone']) if bamboo_data[:mobilePhone].present?
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:email], bamboo_data['email'])

      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:emergencyContactAddress], bamboo_data['addressLine1'], emergency_sub_custom_fields[:addressLine1], false)
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:emergencyContactAddress], bamboo_data['addressLine2'], emergency_sub_custom_fields[:addressLine2], false)
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:emergencyContactAddress], bamboo_data['city'], emergency_sub_custom_fields[:city], false)
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:emergencyContactAddress], bamboo_data['state'], emergency_sub_custom_fields[:state], false)
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:emergencyContactAddress], bamboo_data['zipcode'], emergency_sub_custom_fields[:zipcode], false)
      CustomFieldValue.set_custom_field_value(user, emergency_custom_fields[:emergencyContactAddress], map_country(bamboo_data['country']), emergency_sub_custom_fields[:country], false)
      log("#{user.id}: Update Emergency Contact In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/emergencyContacts"}, {response: emergency_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Emergency Contact In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/emergencyContacts"}, {response: emergency_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_immigration(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Immigration.new(company).fetch(user.bamboo_id)

      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, immigration_custom_fields[:index1], bamboo_data[0]) if !bamboo_data[0].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, immigration_custom_fields[:index2], bamboo_data[1]) if !bamboo_data[1].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, immigration_custom_fields[:index3], bamboo_data[2]) if !bamboo_data[2].instance_of? Hash
      end
      log("#{user.id}: Update Visa Information In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/customImmigration"}, {response: immigration_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Visa Information In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/customImmigration"}, {response: immigration_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_level(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Level.new(company).fetch(user.bamboo_id)
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, level_custom_fields[:index1], bamboo_data[1]) if !bamboo_data[1].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, level_custom_fields[:index2], bamboo_data[2]) if !bamboo_data[2].instance_of? Hash
      end
      log("#{user.id}: Update Level Information In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/customLevel"}, {response: level_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Level Information In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/customLevel"}, {response: level_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_bonus(user, table_name = 'customBonus')
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Bonus.new(company).fetch(user.bamboo_id, table_name)
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, bonus_cutom_fields[:customBonusType], bamboo_data[1]) if !bamboo_data[1].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, bonus_cutom_fields[:customBonusAmount], bamboo_data[2]) if !bamboo_data[2].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, bonus_cutom_fields[:customComments], bamboo_data[3]) if !bamboo_data[3].instance_of? Hash
      end
      log("#{user.id}: Update Bonus Information In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/#{table_name}"}, {response: bonus_cutom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Bonus Information In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/#{table_name}"}, {response: bonus_cutom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_compensation(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Compensation.new(company).fetch(user.bamboo_id).try(:last) || {}
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:startDate], bamboo_data['startDate'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:rate], bamboo_data['rate']['value'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:type], bamboo_data['type'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:paidPer], bamboo_data['paidPer'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:paySchedule], bamboo_data['paySchedule'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:reason], bamboo_data['reason'])
        CustomFieldValue.set_custom_field_value(user, compensation_custom_fields[:exempt], bamboo_data['exempt'])
      end
      log("#{user.id}: Update Compensation Information In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/compensation"}, {response: compensation_custom_fields, bamboo: bamboo_data}, 200)
    rescue Exception => exception
      log("#{user.id}: Update Compensation Information In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/compensation"}, {response: compensation_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_equity(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Equity.new(company).fetch(user.bamboo_id)
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, equity_custom_fields['customIssueDate'], bamboo_data[0]) if !bamboo_data[0].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, equity_custom_fields['custom#ofShares'], bamboo_data[1]) if !bamboo_data[1].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, equity_custom_fields['customComment'], bamboo_data[2]) if !bamboo_data[2].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, equity_custom_fields['customEquityValue'], bamboo_data[3]) if !bamboo_data[3].instance_of? Hash
      end
      log("#{user.id}: Update Equity In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/equity"}, {response: equity_custom_fields, bamboo: bamboo_data}, 200)
    rescue  Exception => exception
      log("#{user.id}: Update Equity In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/equity"}, {response: equity_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_commission(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::Commission.new(company).fetch(user.bamboo_id).try(:last) || {}
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, commission_custom_fields[:amount], bamboo_data['amount'])
        CustomFieldValue.set_custom_field_value(user, commission_custom_fields[:comment], bamboo_data['comment'])
      end
      log("#{user.id}: Update Commission In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/commission"}, {response: commission_custom_fields, bamboo: bamboo_data}, 200)
    rescue  Exception => exception
      log("#{user.id}: Update Commission In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/commission"}, {response: commission_custom_fields, bamboo: exception.message}, 500)
    end

  end

  def update_job_family(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::JobFamily.new(company).fetch(user.bamboo_id)
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, job_family_custom_fields[:customJobFamily], bamboo_data[1]) if !bamboo_data[1].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, job_family_custom_fields[:customJobLevel], bamboo_data[2])  if !bamboo_data[2].instance_of? Hash
      end
      log("#{user.id}: Update Job Family In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/jobFamily"}, {response: job_family_custom_fields, bamboo: bamboo_data}, 200)
    rescue  Exception => exception
      log("#{user.id}: Update Job Family In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/jobFamily"}, {response: job_family_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_req_Id(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::ReqId.new(company).fetch(user.bamboo_id)
      if bamboo_data.present?
        CustomFieldValue.set_custom_field_value(user, req_Id_custom_fields['customReqID#'], bamboo_data[1]) if !bamboo_data[1].instance_of? Hash
        CustomFieldValue.set_custom_field_value(user, req_Id_custom_fields['customChangeReason'], bamboo_data[2]) if !bamboo_data[2].instance_of? Hash
      end
      log("#{user.id}: Update Request Id In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/ReqId"}, {response: req_Id_custom_fields, bamboo: bamboo_data}, 200)
    rescue  Exception => exception
      log("#{user.id}: Update Request Id In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/ReqId"}, {response: req_Id_custom_fields, bamboo: exception.message}, 500)
    end
  end

  def update_job_info(user)
    begin
      bamboo_data = HrisIntegrationsService::Bamboo::JobInformation.new(company).fetch(user.bamboo_id).try(:last) || {}
      CustomFieldValue.set_custom_field_value(user, job_info_custom_fields[:reportsTo], bamboo_data['reportsTo']) if bamboo_data.present?
      log("#{user.id}: Update Job Info In Sapling (#{user.bamboo_id}) - Success", {request: "GET USERS/#{user.bamboo_id}/jobInformation"}, {response: job_info_custom_fields, bamboo: bamboo_data}, 200)
    rescue  Exception => exception
      log("#{user.id}: Update Job Info In Sapling (#{user.bamboo_id}) - Failure", {request: "GET USERS/#{user.bamboo_id}/jobInformation"}, {response: job_info_custom_fields, bamboo: exception.message}, 500)
    end
  end

  private

  def map_country(country)
    index = countries.collect(&:downcase).index(country.downcase) rescue nil
    index.present? ? countries[index] : 'Other'
  end

  def log(action, request, response, status)
    LoggingService::IntegrationLogging.new.create(@company, 'BambooHR', action, request, response, status)
  end
end
