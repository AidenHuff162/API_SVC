class HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling
  attr_reader :company, :adp_wfn_api, :enviornment, :configuration

  delegate :create_loggings, :notify_slack, :format_sapling_phone_number, :format_sapling_address, :fetch_work_assignment, :can_integrate_profile?, :fetch_adp_correlation_id_from_response, to: :helper_service

  COMMUNICATION_METHODS = ['mobiles', 'landlines', 'emails'].freeze

  PERSONAL_INFO_ATTRIBUTES_MAPPING = {
    legalName: 'legal_name', 
    legalAddress: 'legal_address', 
    genderCode: 'gender', 
    maritalStatusCode: 'marital_status', 
    communication: 'communication', 
    raceCode: 'race_and_ethnicity'
  }.freeze

  def initialize(adp_wfn_api)
    @adp_wfn_api = adp_wfn_api
    @company = adp_wfn_api.company
    @enviornment = adp_wfn_api&.api_identifier&.split('_')&.last&.upcase
    @configuration = HrisIntegrationsService::AdpWorkforceNowU::Configuration.new(adp_wfn_api)
    @default_field_names = []
    @custom_field_data = []
  end

  def fetch_updates
    return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment)

    update_by_worker_hire
  end

  def fetch_associate_ids
    return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment)

    update_adp_ids
  end

  private

  def update_adp_ids
    begin
      access_token = configuration.retrieve_access_token
    rescue Exception => e
      notify_slack("*#{company.name}* tried to fetch ADP-#{enviornment} profiles update in Sapling  but received error message that *Access token not retrieved*")
    end

    return unless access_token.present?

    begin
      certificate = configuration.retrieve_certificate
    rescue Exception => e
      notify_slack("*#{company.name}* tried to fetch ADP-#{enviornment} profiles update in Sapling but received error message that *Certificate not retrieved*")
    end

    return unless certificate.present?

    skip = 0
    fetch_more = true

    while fetch_more
      response = events_service.fetch_workers(access_token, certificate, skip)
      set_correlation_id(response)
      break if [204, 200].exclude?(response.status)

      workers = JSON.parse(response.body) rescue nil
      break if workers.blank?

      fetch_more = false if response.status == 204 || (response.status == 200 && workers['workers'].count < 100)
      skip = skip + 100

      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)

      miss_matched_emails = []
      workers['workers'].each do |worker|
        begin
          associate_id = worker['associateOID']
          emails = []
          mismatched_user = []

          personal_email = worker['person']['communication']['emails'][0]['emailUri'].downcase rescue nil
          business_email = worker['businessCommunication']['emails'][0]['emailUri'].downcase rescue nil

          emails.push("#{personal_email}") if personal_email.present?
          emails.push("#{business_email}") if business_email.present?

          if personal_email.present? || business_email.present?
            users = company.users.where('current_stage != ? AND email IN (?)', User.current_stages[:incomplete], emails)
            if users.blank?
              mismatched_user.push("OID: #{associate_id}")
              mismatched_user.push("Business_email: #{business_email}")
              mismatched_user.push("Personal_email: #{personal_email}")
              miss_matched_emails.push(mismatched_user)
            else
              active_work_assignment = fetch_work_assignment({ 'workers': [{'workAssignments': worker['workAssignments']}] }.with_indifferent_access)
              update_user_adp_wfn_id(users.take, associate_id, active_work_assignment)
            end
          end
        rescue Exception => e
          log(500, 'ADP-IDs updates - ERROR', {error: e.message})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      end if workers.present? && workers['workers'].present? && response.status == 200

      log(response.status, 'ADP-IDs updates - Mismatched emails', "#{miss_matched_emails}") if miss_matched_emails.count > 0
    end
    
    adp_wfn_api.update_columns(unsync_records_count: fetch_sapling_users&.count, sync_status: 0)
  end

  def fetch_sapling_users; company.users.where("current_stage != ? AND adp_wfn_#{enviornment.downcase}_id IS NULL AND super_user = ?", User.current_stages[:incomplete], false) end

  def update_by_worker_hire(manager_changed = false)
    users = fetch_users
    count = 0
    access_token, certificate = nil, nil
    
    users.find_each do |user|
      begin
        next unless can_integrate_profile?(@adp_wfn_api, user)
        if count%20 == 0
          begin
            access_token = configuration.retrieve_access_token
          rescue Exception => e
            notify_slack("*#{company.name}* tried to fetch ADP-#{enviornment} profiles update in Sapling  but received error message that *Access token not retrieved*")
          end

          if access_token.blank?
            break
          end

          begin
            certificate = configuration.retrieve_certificate
          rescue Exception => e
            notify_slack("*#{company.name}* tried to fetch ADP-#{enviornment} profiles update in Sapling but received error message that *Certificate not retrieved*")
          end

          if certificate.blank?
            break
          end
        end

        count = count + 1
        response = events_service.fetch_worker(access_token, certificate, fetch_adp_wfn_id(user))
        set_correlation_id(response)
        
        if response&.status != 200
          if response&.status != 204
            notify_slack("*#{company.name}* tried to fetch ADP-#{enviornment} (#{user.full_name}'s - #{user.id}) profiles update through worker in Sapling but received message that *#{response.status}*")
            log(500, "Update user in Sapling (#{user.id}) through worker - Failure", {result: response.status}, {request: "GET WORKER/#{user.id}"})
          end
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)

          next
        end

        response = JSON.parse(response&.body)
        
        active_work_assignment = fetch_work_assignment(response)
        worker = response['workers'][0] rescue {}
        if active_work_assignment.present?
          params = build_worker_hire_params(user, active_work_assignment, worker)
          if ((worker['workerDates']['rehireDate'].present? && 
            active_work_assignment['hireDate'] && 
            worker['workerDates']['rehireDate'] == active_work_assignment['hireDate']) || 
            (active_work_assignment['hireDate'].present? && 
            active_work_assignment['actualStartDate'] && 
            active_work_assignment['hireDate'] != active_work_assignment['actualStartDate']) && 
            active_work_assignment['terminationDate'].blank?)
            cancel_offboarding(user,  worker['workerDates']['rehireDate'])
            params[:user][:rehired] = true
          end

          user.update_column(:adp_work_assignment_id, active_work_assignment['itemID'])
          if company.is_using_custom_table.present?
            update_user_custom_table_information(user, params)
          else
            temp_user = user.attributes
            update_user_information(user, params)
            send_updates_to_webhooks(company.id, {default_data_change: @default_field_names, user: user.id, temp_user: temp_user, webhook_custom_field_data: @custom_field_data&.flatten})
          end

          update_user_personal_information(user, worker)
          log(200, "Update user in Sapling (#{user.id}) through worker - Success", {result: worker}, {request: "GET WORKER/#{user.id}"})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        end
      rescue Exception => e
        notify_slack("*#{company.name}* tried to fetch ADP-#{enviornment} (#{user.full_name}'s - #{user.id}) profiles update through worker in Sapling but received error that *#{e.message}*")
        log(500, "Update user in Sapling (#{user.id}) through worker - Failure", {result: e.message}, {request: "GET WORKER/#{user.id}"})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    end
  end

  def update_user_personal_information(user, data)
    person = data.dig('person')
    business_communication = data.dig('businessCommunication')
    worker_dates = data.dig('workerDates')
    
    PERSONAL_INFO_ATTRIBUTES_MAPPING.each do |key, method_name|
      value = person&.dig(key.to_s)
      send("update_#{method_name}", user, value) if value.present?
    end

    update_business_communication_email(user, business_communication.dig('emails')&.dig(0)&.dig('emailUri')) if business_communication&.dig('emails')&.dig(0)&.dig('emailUri').present?
    update_termination_status(user, worker_dates.dig('terminationDate')) if worker_dates&.dig('terminationDate').present?
  end

  def build_worker_hire_params(user, active_work_assignment, worker)
    params = { user: {}, custom_field: {} }
    if @company.domain == 'popsugar.saplingapp.io'
      string_fields = worker['customFieldGroup']['stringFields'] rescue []
      business_title = string_fields.try(:select) { |string_field| string_field['nameCode']['codeValue'] == 'Business Title' }.last rescue {}

      params[:user][:title] = business_title['stringValue'] || user.title
    else
      params[:user][:title] = active_work_assignment['jobTitle'] || user.title
    end

    home_organizational_units = active_work_assignment['homeOrganizationalUnits'] rescue []

    home_organizational_units.try(:each) do |home_organizational_unit|
      code_value = home_organizational_unit['typeCode']['codeValue']
      case code_value.try(:downcase)
      when company.department_mapping_key.downcase
        team_id = fetch_team_by_adp_code(home_organizational_unit['nameCode']['codeValue'], home_organizational_unit['nameCode']['shortName'] || home_organizational_unit['nameCode']['longName']).id rescue nil
        params[:user][:team_id] = team_id || user.team_id
      when 'business unit'
        business_unit = (home_organizational_unit['nameCode']['shortName'] || home_organizational_unit['nameCode']['longName']) rescue nil
        params[:custom_field][:business_unit] = business_unit || user.get_custom_field_value_text('Business Unit')
      end
    end

    payroll_group_code = active_work_assignment['payrollGroupCode'] rescue nil
    params[:custom_field][:company_code] = payroll_group_code || user.get_custom_field_value_text('ADP Company Code')

    location_id = fetch_location_by_adp_code(active_work_assignment['homeWorkLocation']['nameCode']['codeValue']).id rescue nil
    params[:user][:location_id] = location_id || user.location_id

    manager_id = fetch_user(active_work_assignment['reportsTo'][0]['associateOID']).id rescue nil
    params[:user][:manager_id] = manager_id || user.manager_id

    employment_status = (active_work_assignment['workerTypeCode']['shortName'] || active_work_assignment['workerTypeCode']['longName']) rescue nil
    params[:custom_field][:employment_status] = employment_status || user.employee_type_field_option&.option

    base_remuneration = active_work_assignment['baseRemuneration']
    if base_remuneration.present?
      if base_remuneration['hourlyRateAmount'].present?
        base_remuneration_rate_amount = base_remuneration['hourlyRateAmount']
      elsif base_remuneration['dailyRateAmount'].present?
        base_remuneration_rate_amount = base_remuneration['dailyRateAmount']
      elsif base_remuneration['payPeriodRateAmount'].present?
        base_remuneration_rate_amount = base_remuneration['payPeriodRateAmount']
      end

      if base_remuneration_rate_amount.present?
        if company.is_using_custom_table?.blank?
          rate_type = (base_remuneration_rate_amount['nameCode']['shortName'] || base_remuneration_rate_amount['nameCode']['longName']) rescue nil
          params[:custom_field][:rate_type] = rate_type || user.get_custom_field_value_text(nil, false, nil, company.custom_fields.find_by(name: 'Rate Type', custom_table_id: nil))

          pay_rate = user.get_custom_field_value_text(nil, true, nil, company.custom_fields.find_by(name: 'Pay Rate', custom_table_id: nil)) || {}
          params[:custom_field][:pay_rate] = {}

          amount_value = base_remuneration_rate_amount['amountValue'] rescue nil
          currency_code = base_remuneration_rate_amount['currencyCode'] rescue nil
          params[:custom_field][:pay_rate][:amount_value] = amount_value || pay_rate[:currency_value]
          params[:custom_field][:pay_rate][:currency_code] = currency_code || pay_rate[:currency_type]
        else
          params[:custom_field][:rate_type] = (base_remuneration_rate_amount['nameCode']['shortName'] || base_remuneration_rate_amount['nameCode']['longName']) rescue nil
          params[:custom_field][:pay_rate] = {}
          params[:custom_field][:pay_rate][:amount_value] = base_remuneration_rate_amount['amountValue'] rescue nil
          params[:custom_field][:pay_rate][:currency_code] = base_remuneration_rate_amount['currencyCode'] rescue nil
        end
      end

      if company.is_using_custom_table?.blank?
        pay_frequency = (active_work_assignment['payCycleCode']['shortName'] || active_work_assignment['payCycleCode']['longName']) rescue nil
        params[:custom_field][:pay_frequency] = pay_frequency || user.get_custom_field_value_text(nil, false, nil, company.custom_fields.find_by(name: 'Pay Frequency', custom_table_id: nil))
      else
        params[:custom_field][:pay_frequency] = (active_work_assignment['payCycleCode']['shortName'] || active_work_assignment['payCycleCode']['longName']) rescue nil
      end
    end

    status_code = active_work_assignment['assignmentStatus']['statusCode']

    params
  end

  def update_user_information(user, params)
    if params[:user].present?
      params[:user].delete(:rehired) if params[:user].has_key?(:rehired)
      @default_field_names = params[:user]&.stringify_keys&.keys
      user.update!(params[:user])
    end

    if params[:custom_field].present?
      old_value = user.get_custom_field_value_text("ADP Company Code")
      CustomFieldValue.set_custom_field_value(user, 'ADP Company Code', params[:custom_field][:company_code])
      update_old_custom_field_value('ADP Company Code', old_value)
      old_value = user.get_custom_field_value_text("Business Unit")
      CustomFieldValue.set_custom_field_value(user, 'Business Unit', params[:custom_field][:business_unit])
      update_old_custom_field_value('Business Unit', old_value)
      old_value = user.get_custom_field_value_text("Employment Status")
      CustomFieldValue.set_custom_field_value(user, 'Employment Status', params[:custom_field][:employment_status])
      update_old_custom_field_value('Employment Status', old_value)
      old_value = user.get_custom_field_value_text("Rate Type")
      CustomFieldValue.set_custom_field_value(user, nil, params[:custom_field][:rate_type], nil, true, company.custom_fields.find_by(name: 'Rate Type', custom_table_id: nil))
      update_old_custom_field_value('Rate Type', old_value)
      old_value = user.get_custom_field_value_text("Pay Frequency")
      CustomFieldValue.set_custom_field_value(user, nil, params[:custom_field][:pay_frequency], nil, true, company.custom_fields.find_by(name: 'Pay Frequency', custom_table_id: nil))
      update_old_custom_field_value('Pay Frequency', old_value)

      if params[:custom_field][:pay_rate].present?
        pay_rate = company.custom_fields.find_by(name: 'Pay Rate', custom_table_id: nil)
        old_value = user.get_custom_field_value_text("Pay Rate")
        CustomFieldValue.set_custom_field_value(user, nil, params[:custom_field][:pay_rate][:amount_value], 'Currency Value', false, pay_rate, false, false)
        CustomFieldValue.set_custom_field_value(user, nil, params[:custom_field][:pay_rate][:currency_code], 'Currency Type', false, pay_rate, false, true)
        update_old_custom_field_value('Pay Rate', old_value)
      end
    end
    @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
  end

  def update_user_custom_table_information(user, params)
    integration_custom_tables_service = ::IntegrationsService::ManageIntegrationCustomTables.new(company, fetch_integration_type)

    params[:user][:state] = user.state if params[:user].key?(:state).blank?
    integration_custom_tables_service.manage_role_information_custom_table(user, params)
    integration_custom_tables_service.manage_employment_status_custom_table(user, params) if user.active?
    integration_custom_tables_service.manage_compensation_custom_table(user, params)
    @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
  end

  def update_legal_name(user, legal_name)
    preferred_name = legal_name['nickName']
    first_name = legal_name['givenName']
    last_name = legal_name['familyName1']
    middle_name = legal_name['middleName']
    @default_field_names.push("preferred_name", "first_name", "last_name")
    old_value = user.get_custom_field_value_text("Middle Name")
    CustomFieldValue.set_custom_field_value(user, 'Middle Name', middle_name)
    update_old_custom_field_value('Middle Name', old_value)
    user.update!(preferred_name: preferred_name, first_name: first_name, last_name: last_name)
  end

  def update_marital_status(user, marital_status_code)
    marital_status_name = marital_status_code['shortName'] || marital_status_code['longName']
    old_value = user.get_custom_field_value_text("Federal Marital Status")
    CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', marital_status_name)
    update_old_custom_field_value('Federal Marital Status', old_value)
  end

  def update_gender(user, gender_code)
    gender_name = gender_code['shortName'] || gender_code['longName']
    old_value = user.get_custom_field_value_text("Gender")
    CustomFieldValue.set_custom_field_value(user, 'Gender', gender_name)
    update_old_custom_field_value('Gender', old_value)
  end

  def update_race_and_ethnicity(user, race_code)
    race_id_method_name = race_code['identificationMethodCode']['shortName'] || race_code['identificationMethodCode']['longName']
    ethnicity_name = race_code['shortName'] || race_code['longName']
    old_value_race = user.get_custom_field_value_text("Race ID Method")
    old_value_ethnicity = user.get_custom_field_value_text("Race/Ethnicity")
    CustomFieldValue.set_custom_field_value(user, 'Race ID Method', race_id_method_name)
    CustomFieldValue.set_custom_field_value(user, 'Race/Ethnicity', ethnicity_name)
    update_old_custom_field_value('Race ID Method', old_value_race)
    update_old_custom_field_value('Race/Ethnicity', old_value_ethnicity)
  end

  def update_communication(user, communication)
    COMMUNICATION_METHODS.each do |method_name|
      value = communication.dig(method_name)&.dig(0)
      send("update_personal_communication_#{method_name}", user, value) if value.present?
    end
  end

  def update_personal_communication_landlines(user, landline_communication)
    home_phone_number = format_sapling_phone_number(landline_communication)
    old_value = user.get_custom_field_value_text('Home Phone Number')
    CustomFieldValue.set_custom_field_value(user, 'Home Phone Number', home_phone_number[:country_dialing], 'Country', false)
    CustomFieldValue.set_custom_field_value(user, 'Home Phone Number', home_phone_number[:area_dialing], 'Area code', false)
    CustomFieldValue.set_custom_field_value(user, 'Home Phone Number', home_phone_number[:dial_number], 'Phone', false, nil, false, true)
    update_old_custom_field_value('Home Phone Number', old_value)
  end

  def update_personal_communication_mobiles(user, mobile_communication)
    mobile_phone_number = format_sapling_phone_number(mobile_communication)
    old_value = user.get_custom_field_value_text("Mobile Phone Number")
    CustomFieldValue.set_custom_field_value(user, 'Mobile Phone Number', mobile_phone_number[:country_dialing], 'Country', false)
    CustomFieldValue.set_custom_field_value(user, 'Mobile Phone Number', mobile_phone_number[:area_dialing], 'Area code', false)
    CustomFieldValue.set_custom_field_value(user, 'Mobile Phone Number', mobile_phone_number[:dial_number], 'Phone', false, nil, false, true)
    update_old_custom_field_value('Mobile Phone Number', old_value)
  end

  def update_personal_communication_emails(user, personal_email)
    personal_email = personal_email.dig('emailUri')
    @default_field_names.push("personal_email")
    user.update!(personal_email: personal_email)
  end

  def update_business_communication_email(user, email)
    @default_field_names.push("email")
    user.update!(email: email)
  end

  def update_legal_address(user, legal_address)
    address = format_sapling_address(legal_address)
    old_value = user.get_custom_field_value_text("Home Address")
    CustomFieldValue.set_custom_field_value(user, 'Home Address', address[:line1], 'Line 1', false)
    CustomFieldValue.set_custom_field_value(user, 'Home Address', address[:line2], 'Line 2', false)
    CustomFieldValue.set_custom_field_value(user, 'Home Address', address[:city], 'City', false)
    CustomFieldValue.set_custom_field_value(user, 'Home Address', address[:zip], 'Zip', false)
    CustomFieldValue.set_custom_field_value(user, 'Home Address', address[:state], 'State', false)
    CustomFieldValue.set_custom_field_value(user, 'Home Address', address[:country], 'Country', false, nil, false, true)
    update_old_custom_field_value('Home Address', old_value)
  end

  def update_termination_status(user, termination_date)
    if user.present? && user.active? && user.departed?.blank?
      if termination_date.present?
        original_user = user.dup
        if company.is_using_custom_table.present?
          params = { eligible_for_rehire: user.eligible_for_rehire, termination_type: user.termination_type, last_day_worked: get_user_last_day_worked(user, termination_date), termination_date: termination_date }
          ::IntegrationsService::ManageIntegrationCustomTables.new(company, fetch_integration_type).manage_terminated_employment_status_table_snapshot(user, params)
        else
          user.tasks.update_all(owner_id: nil)
          user.update_column(:remove_access_timing, 'remove_immediately') if termination_date.to_date < Date.today
          update_params = { termination_date: termination_date, last_day_worked: get_user_last_day_worked(user, termination_date) }
          user.update!(update_params)
          user.offboarding!
        end
        ::Inbox::UpdateScheduledEmail.new.update_scheduled_user_emails(user.reload, original_user)
      end
    end
  end

  def get_user_last_day_worked(user, termination_date)
    user.last_day_worked.present? ? user.last_day_worked : termination_date
  end

  def fetch_user(adp_wfn_id)
    enviornment == 'US' ? company.users.where(adp_wfn_us_id: adp_wfn_id).take : company.users.where(adp_wfn_can_id: adp_wfn_id).take
  end

  def fetch_users
    enviornment == 'US' ? company.users.where.not(adp_wfn_us_id: nil) : company.users.where.not(adp_wfn_can_id: nil)
  end

  def fetch_team_by_adp_code(code_value, team_name)
    return unless code_value.present? || team_name.present?
    
    team = company.teams.get_team_by_name(company, team_name)
    team.get_adp_wfn_code_value(enviornment, code_value)
  end

  def fetch_location_by_adp_code(code_value)
    return unless code_value.present?
    enviornment == 'US' ? company.locations.where(adp_wfn_us_code_value: code_value).take : company.locations.where(adp_wfn_can_code_value: code_value).take
  end

  def fetch_adp_wfn_id(user)
    enviornment == 'US' ? user.adp_wfn_us_id : user.adp_wfn_can_id
  end

  def fetch_integration_type
    enviornment == 'US' ? CustomTableUserSnapshot.integration_types[:adp_integration_us] : CustomTableUserSnapshot.integration_types[:adp_integration_can]
  end

  def update_user_adp_wfn_id(user, adp_wfn_id, work_assignment)
    return unless user.present?

    if adp_wfn_id.present?
      if enviornment == 'US' && (user.adp_wfn_us_id.blank? || (user.adp_wfn_us_id.present? && user.adp_wfn_us_id != adp_wfn_id))
        user.update_column(:adp_wfn_us_id, adp_wfn_id)
      elsif enviornment == 'CAN' && (user.adp_wfn_can_id.blank? || (user.adp_wfn_can_id.present? && user.adp_wfn_can_id != adp_wfn_id))
        user.update_column(:adp_wfn_can_id, adp_wfn_id)
      end
    end

    @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
    user.update_column(:adp_work_assignment_id, work_assignment['itemID']) if work_assignment.present? && work_assignment['itemID'].present?
  end

  def helper_service
    HrisIntegrationsService::AdpWorkforceNowU::Helper.new
  end

  def events_service
    HrisIntegrationsService::AdpWorkforceNowU::Events.new
  end

  def set_correlation_id(response)
    @correlation_id = fetch_adp_correlation_id_from_response(response)
  end

  def log(status, action, result, request = nil)
    result.concat(", adp_correlation_id: #{@correlation_id}") if result.class == String
    result.merge!({adp_correlation_id: @correlation_id}) if result.class == Hash
    create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result, request)
  end

  def cancel_offboarding(user, rehire_date)
    return unless user.termination_date.present? && user.inactive?
    
    user.last_day_worked = nil
    user.termination_type = nil
    user.termination_date = nil
    user.eligible_for_rehire = nil
    user.is_rehired = true
    user.state = 'active'
    user.remove_access_state = "pending"
    user.current_stage = :pre_start
    user.start_date = rehire_date if rehire_date.present?
    user.save!
    user.onboarding!

    ::Gsuite::ManageAccount.new.reactivate_gsuite_account(user) if !user.gsuite_account_exists
    user.reset_pto_balances
  end

  def update_old_custom_field_value (field_name, old_value)
    @custom_field_data.push({name: field_name, old_value: old_value})
  end

  def send_updates_to_webhooks(company_id, event_data)
    WebhookEvents::ManageWebhookPayloadJob.perform_async(company_id, event_data)
    @custom_field_data = [], @default_field_names = []
  end
end
