class HrisIntegrationsService::Xero::Helper
  def fetch_integration(company, user=nil, instance_id=nil)
    if user.present? && instance_id.blank?
      company.integration_instances.where(api_identifier: 'xero').find_each do |instance|
        return instance if can_integrate_profile?(instance, user)
      end
    elsif user.blank? && instance_id.present?
      company.integration_instances.find_by(id: instance_id)  
    else
      company.integration_instances.where(api_identifier: "xero").first
    end
  end
 

  def create_loggings company, integration_name, state, action, result, api_request = 'No Request'
    integration = fetch_integration(company)
    
    if integration.present?
      if [401, 403, 404].include?(state) 
        integration.update_column(:sync_status, 2)
      elsif [200, 201, 204].include?(state) 
        integration.update_column(:sync_status, 0)
      else
        integration.update_column(:sync_status, 3)
      end
    end

    LoggingService::IntegrationLogging.new.create(
      company,
      integration_name,
      action,
      api_request,
      result,
      state.to_s
    )
  end

  def can_integrate_profile?(integration, user)
    return unless integration.present? && integration.filters.present?
      
    filter = integration.filters
    (apply_to_location?(filter, user) && apply_to_team?(filter, user) && apply_to_employee_type?(filter, user))
  end

  def apply_to_location?(filter, user)
    location_ids = filter['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filter, user)
    team_ids = filter['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filter, user)
    employee_types = filter['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end

 # :nocov:
  def refresh_token xero
    begin
      resp = true
      b = xero&.expires_in.in_time_zone(xero&.company.time_zone)
      a = xero&.company.time
      if ((a-b)/1.minutes).to_i > 25
        retries ||= 1
        response = refresh(xero.reload.refresh_token)
        if response.ok?
          body = JSON.parse(response.body)
          xero.refresh_token(body['refresh_token'])
          xero.access_token(body['access_token'])
          xero.expires_in(xero.company.time)
          xero.save!
          create_loggings(xero.company, 'Xero', response.code, 'Access Token Renewal - Success', { response: response.to_s})
        else
          resp = false
          create_loggings(xero.company, 'Xero', response.code, 'Access Token Renewal - Failure', { response: response.to_s})
        end
      end
    rescue Exception => e
      resp = false
      create_loggings(xero.company, 'Xero', 401, 'Access Token Renewal - Failure', { params: client, message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(xero.company)
      
      retry if (retries += 1) < 10
      
      raise if retries == 10
    ensure
      return resp
    end
  end
 # :nocov:

  def refresh(refresh_token)
    HTTParty.post("https://identity.xero.com/connect/token",
      body: "grant_type=refresh_token&refresh_token=#{refresh_token}",
      headers: { content_type: 'application/x-www-form-urlencoded', authorization: 'Basic ' + Base64.strict_encode64(ENV['XERO_CLIENT_ID'] + ':' + ENV['XERO_CLIENT_SECRET']) }
    )
  end
 
  def get_state_abbreviation(state)
    case state
    when 'Australian Capital Territory'
      return 'ACT'
    when 'New South Wales'
      return 'NSW'
    when 'Northern Territory'
      return 'NT'
    when 'Queensland'
      return 'QLD'
    when 'South Australia'
      return 'SA'
    when 'Tasmania'
      return 'TAS'
    when 'Victoria'
      return 'VIC'
    when 'Western Australia'
      return 'WA'
    end
  end

  def getStatus(user)
    return "ACTIVE" if user.active?

    return "TERMINATED"
  end


  def get_gender_code(gender)
    case gender.downcase
    when 'male'
      return 'M'
    when 'female'
      return 'F'
    when 'not specified'
      return 'N'
    else
      return 'I'
    end
  end

  def get_employee_type(employee_type)
    employee_type_hash = get_employee_type_hash
    employee_type_hash[employee_type_hash.keys.select{ |key| employee_type.downcase.start_with?(key) }.first]
  end

  def get_calculation_type(calculation_type)
    case calculation_type.downcase
    when 'user earning rate'
      return 'USEEARNINGSRATE'
    when 'enter earning rate'
      return 'ENTEREARNINGSRATE'
    when 'annual salary'
      return 'ANNUALSALARY'
    end
  end

  def get_residency_status_type(residency_status)
    case residency_status.downcase
    when 'australian resident'
      return 'AUSTRALIANRESIDENT' 
    when 'foreign resident'
      return 'FOREIGNRESIDENT' 
    when 'working holiday maker'
      return 'WORKINGHOLIDAYMAKER' 
    end    
  end

  def validate_tfn(tfn)
    (tfn.to_s.size > 8) && (tfn.is_a? Integer)
  end

  def annual_units(pto_policy) 
    policy_rate = pto_policy.accrual_rate_unit == 'days' ? (get_policy_tenureship_rate(pto_policy) * pto_policy.working_hours) : get_policy_tenureship_rate(pto_policy)
    policy_rate = policy_rate * get_number_of_aquisition_period_of_iterations(pto_policy)
  end

  def get_policy_tenureship_rate(pto_policy)
    policy_tenureships = pto_policy.policy_tenureships
    return pto_policy.accrual_rate_amount if policy_tenureships.blank?
    employement_years = ((current_date(pto_policy.user.company) - pto_policy.user.start_date) / 365).floor
    return pto_policy.accrual_rate_amount if employement_years < 1 || policy_tenureships.where("year <= #{employement_years}").blank?
    return pto_policy.accrual_rate_amount + (policy_tenureships.where("year <= #{employement_years}").max_by {|obj| obj.year }).amount
  end

  def get_number_of_aquisition_period_of_iterations(pto_policy)
    iterations = 0
    case pto_policy.rate_acquisition_period
      when 'month'
        iterations = 12
      when 'week'
        iterations = 52
      when 'day'
        iterations = 365
      when 'hour_worked'
        iterations = 365 * pto_policy.working_hours
      when 'year'
        iterations = 1
      end
    iterations
  end

  def current_date(company)
    Time.now.in_time_zone(company.time_zone).to_date
  end

  def verify_state_and_fetch_company(payload)
    begin 
      ids = JsonWebToken.decode(payload[:state])
      company = Company.find_by(id: ids["company_id"].to_i)
      instance = company.integration_instances.find_by(id: ids["instance_id"].to_i)
      user_id = ids["user_id"].to_i
      if instance.present?
        return company, instance.id, user_id
      else
        raise CanCan::AccessDenied
      end
    rescue Exception => e
      raise CanCan::AccessDenied
    end
  end

  def get_salary(user)
    annual_salary_field = user.company.custom_fields.find_by(name: 'Annual Salary')
    
    annual_salary = 
      if annual_salary_field && annual_salary_field.currency?
        user.get_custom_field_value_text('Annual Salary', false, 'Currency Value')
      else
        user.get_custom_field_value_text('Annual Salary')
      end
    
    annual_salary&.gsub!(',','') if annual_salary&.include?(',')
    return annual_salary
  end

  def get_termination_reason(termination_reason)
    case termination_reason&.downcase
    when 'voluntary cessation'
      return 'V'
    when 'ill health'
      return 'I'
    when 'deceased'
      return 'D'
    when 'redundancy'
      return 'R'
    when 'dismissal'
      return 'F'
    when 'contract cessation'
      return 'C'
    when 'transfer'
      return 'T'
    end
  end

  def merge_bank_accounts(accounts_response, params_builder, user)
    account_index = accounts_response.find_index{ |m| m['Remainder'] }
    params = params_builder.build_bank_detail_params(user)
    accounts_response[account_index] = params['Employee']['BankAccounts'].first
    params['Employee']['BankAccounts'] = accounts_response
    params
  end

  private

  def get_employee_type_hash
    { 'full time' => 'FULLTIME',
      'part time' => 'PARTTIME',
      'casual' => 'CASUAL',
      'labour hire' => 'LABOURHIRE',
      'super in come stream' => 'SUPERINCOMESTREAM' 
    }
  end

end
