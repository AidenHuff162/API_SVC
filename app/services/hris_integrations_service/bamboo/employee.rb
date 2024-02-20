class HrisIntegrationsService::Bamboo::Employee < HrisIntegrationsService::Bamboo::Initializer
  attr_reader :bamboo_fields

  def initialize(company)
    super(company)
    @bamboo_fields = [
      'firstName', 'lastName', 'workEmail', 'homeEmail', 'hireDate', 'jobTitle',
      'lastChanged', 'nickname', 'id', 'terminationDate', 'employmentHistoryStatus',
      'status', 'photoUploaded', 'photoUrl', 'supervisorEId', 'dateOfBirth', 'ssn',
      'ethnicity', 'mobilePhone', 'homePhone', 'maritalStatus', 'gender', 'middleName',
      'address1', 'address2', 'city', 'zipcode', 'state', 'country', 'customAllergies',
      'customShirtsize', 'payRate', 'payType', 'payPeriod', 'exempt', 'paidPer', 'standardHoursPerWeek',
      'customSpiritAnimal', 'customDietaryRestrictions', 'customSyncToSequoia', 'customT-ShirtSize',
      'customOneInterestingFact', 'customADPFileNumber', 'customETHNICITY', 'eeo', 'sin', 'division',
      'customGroup', 'customTeam', 'customGenderIdentity', 'customPronouns', 'customCostCenter', 'customEthnicity/Race',
      'customControlledSubstanceLicense(DC)', 'customDEA', 'customDEA(DC)', 'customDEA(IL)', 'customDEA(NY)', 'customDEA(WA)',
      'customDosespotID', 'employeeNumber', 'legacyUserId', 'customNPINumber', 'customT-Shirt/JacketSize', 'employee_access',
      'linkedIn', 'customgithubusername', 'customWebsiteBio', 'originalHireDate', 'customGender']

    @bamboo_fields.push company.location_mapping_key.try(:downcase)
    @bamboo_fields.push company.department_mapping_key.try(:downcase)

    group_fields = fetch_custom_groups
    @bamboo_fields = @bamboo_fields + group_fields if group_fields.present?
    @bamboo_fields = @bamboo_fields.select(&:present?).uniq
  end

  def fetch_bamboo_employees
    return if !bamboo_api_initialized?

    client = Bamboozled.client(subdomain: bamboo_api.subdomain, api_key: bamboo_api.api_key)
    client.employee.all(bamboo_fields)
  end

  def fetch_updated_bamboo_employees
    return if !bamboo_api_initialized?

    client = Bamboozled.client(subdomain: bamboo_api.subdomain, api_key: bamboo_api.api_key)
    client.employee.last_changed(1.week.ago)
  end

  def find_bamboo_employee(bamboo_id)
    return if !bamboo_api_initialized?
    client = Bamboozled.client(subdomain: bamboo_api.subdomain, api_key: bamboo_api.api_key)
    client.employee.find(bamboo_id, bamboo_fields)
  end

  def create_bamboo_employee(user, data)
    return if !bamboo_api_initialized?
    bamboo_id = nil
    if !bamboo_api.can_export_new_profile.present?
      log("#{user.id}: Unable to Create User In Bamboo - Success", {request: data}, {response: 'Enable Toggle To Create User'}, 200)
    else
      begin
        client = Bamboozled.client(subdomain: bamboo_api.subdomain, api_key: bamboo_api.api_key)
        client = client.employee.add(data)
        bamboo_id = client['headers']['location'].split('/').try(:last)

        log("#{user.id}: Create User In Bamboo (#{bamboo_id}) - Success", {request: data}, {response: client}, 200)

      rescue Exception => exception

        log("#{user.id}: Create User In Bamboo (#{bamboo_id}) - Failure", {request: data}, {response: exception.message}, 500)

        message = "*#{user.company.name}* tried to create a new profile but there was an issue sending *#{user.full_name}*'s information to *BambooHR*. We received... *#{exception.inspect}*"
        ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
            IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:human_resource_information_system]))
      end
    end

    bamboo_id
  end

  def update_bamboo_employee(user, data)
    return if !bamboo_api_initialized?

    begin
      client = Bamboozled.client(subdomain: bamboo_api.subdomain, api_key: bamboo_api.api_key)
      client = client.employee.update(user.bamboo_id, data)
      log("#{user.id}: Upload User In Bamboo (#{user.bamboo_id}) - Success", {request: data}, {response: client}, 200)
    rescue Exception => exception
      log("#{user.id}: Upload User In Bamboo (#{user.bamboo_id}) - Failure", {request: data}, {response: exception.message}, 500)
    end
  end

  private

  def fetch_custom_groups
    return if company.blank?
    custom_fields = company.custom_fields.where("integration_group > ?", CustomField.integration_groups[:no_integration])
    custom_fields.pluck(:mapping_key).select(&:present?).map(&:downcase)
  end
end
