class HrisIntegrationsService::Xero::UpdateSaplingProfileInXero
  attr_reader :user, :company, :params_builder_service, :xero
  delegate :create_loggings, :merge_bank_accounts, to: :helper_service
  delegate :post_request, :fetch_user, to: :hris_service

  def initialize(user, xero)
    @user = user
    @company = user.company
    @xero = xero
   
    initialize_service
  end

  def update_profile(field_name)
    return unless field_name.present?
    case field_name.downcase
    when 'first_name', 'last_name'
      change_name
    when 'date of birth'
      change_date_of_birth
    when 'line1', 'line2', 'zip', 'city', 'state'
      change_home_address
    when 'start_date'
      change_start_date
    when 'title'
      change_job_title
    when 'personal_email'
      change_email
    when 'title'
      change_title
    when 'gender'
      change_gender
    when 'mobile phone number'
      change_mobile
    when 'home phone number'
      change_phone
    when 'tax file number', 'residency status', 'employment status'
      change_employment_basis
    when 'calculation type', 'annual salary', 'hours per week', 'rate per unit'
      change_calculation_type    
    when 'middle name'
      change_middle_name    
    when 'account name', 'account number', 'bank name', 'bsb/sort code'
      change_bank_details
    end

  end

  def terminate_user
    terminate
  end
  
  private
  
  def initialize_service
    @params_builder_service = HrisIntegrationsService::Xero::ParamsBuilder.new
  end 
  
  def change_name
    params = params_builder_service.build_name_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - First Name, Last Name - Success', {params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - First Name, Last Name - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_date_of_birth
    params = params_builder_service.build_date_of_birth_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Date Of Birth - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Date Of Birth - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_home_address
    params = params_builder_service.build_home_address_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Home Address - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Home Address - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_start_date
    params = params_builder_service.build_start_date_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Start Date - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Start Date - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_job_title
    params = params_builder_service.build_job_title_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Job Title - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Job Title - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_email
    params = params_builder_service.build_email_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Email Address - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Email Address - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_title
    params = params_builder_service.build_title_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Title - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Title - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

    def change_gender
    params = params_builder_service.build_gender_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Gender - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Gender - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

    def change_mobile
    params = params_builder_service.build_mobile_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Mobile - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Mobile - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

    def change_phone
    params = params_builder_service.build_phone_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Phone - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Phone - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

    def terminate
    params = params_builder_service.build_terminated_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Terminate User - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Terminate User - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_employment_basis
    params = params_builder_service.build_employment_basis_params(user).to_xml(root: "Employees")

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Employement Basis - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Employement Basis - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_calculation_type
    params = params_builder_service.build_calculation_type_params(user, xero).to_xml(root: "Employees")

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Calculation Type - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Calculation Type - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_middle_name
    params = params_builder_service.build_middle_name_params(user)

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Middle Name - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Middle Name - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_bank_details
    response = fetch_user(user)
    accounts_response = response['Employees']&.first.try(:dig, 'BankAccounts')
    accounts_count = accounts_response.count
    if accounts_count > 1
      params = merge_bank_accounts(accounts_response, params_builder_service, user).to_xml(root: 'Employees')
    else
      params = params_builder_service.build_bank_detail_params(user).to_xml(root: 'Employees')
    end

    begin
      response = post_request(params)
      log(response.code, 'Update Profile in Xero - Bank Information - Success', { params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in Xero - Bank Information - ERROR', { params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def log(status, action, result, request = nil)
    create_loggings(company, "Xero", status, action, result, request)
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end 

  def hris_service
    HrisIntegrationsService::Xero::HumanResource.new(company, nil, @user.id)
  end
end
