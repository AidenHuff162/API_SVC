class IntegrationsService::UpdateIntegrationThroughFlatfile
  attr_reader :user, :user_updated_changes, :integration_custom_fields, :company
  
  def initialize(user, user_updated_changes = [], integration_custom_fields = nil)
    @user = user
    @company = user.company
    @user_updated_changes = user_updated_changes
    @integration_custom_fields = integration_custom_fields
  end

  def perform
    return unless user.present?
    manage_integrations()
  end

  private

  def manage_integrations
    integration_type, auth_type = company.integration_type, company.authentication_type

    if company.integration_types.include?('bamboo_hr') && user.bamboo_id.present?
      send_updates_to_bamboo()
    end

    if auth_type == 'one_login' && user.one_login_id.present?
      send_updates_to_one_login()
    end

    if user.workday_id.present? && should_send_updates_to?('workday')
      send_updates_to_workday
    end

    if should_send_updates_to?('namely') && user.namely_id.present?
      send_updates_to_namely()
    end
    
    if company.is_xero_integrated? && user.xero_id.present?
      send_updates_to_xero()
    end

    if auth_type == 'okta' && user.okta_id.present? && company.integration_instances&.find_by(api_identifier: 'okta', state: :active)&.enable_update_profile
      send_updates_to_okta()
    end

    if company.get_gsuite_account_info.present? && (company.subdomain == 'warbyparker' || Rails.env.staging? || Rails.env.test?) && !user.incomplete?
      send_updates_to_gsuite()
    end

    if company.can_provision_adfs? && user.active_directory_object_id.present?
      send_updates_to_adfs()
    end

    if user.learn_upon_id.present? && should_send_updates_to?('learn_upon')
      send_updates_to_learn_upon()
    end

    if user.lessonly_id.present? && should_send_updates_to?('lessonly')
      send_updates_to_lessonly()
    end

    if user.deputy_id.present? && should_send_updates_to?('deputy')
      send_updates_to_deputy()
    end

    if user.trinet_id.present? && should_send_updates_to?('trinet')
      send_updates_to_trinet()
    end

    if user.fifteen_five_id.present? && should_send_updates_to?('fifteen_five')
      send_updates_to_fifteen_five()
    end

    if company.gusto_feature_flag && user.gusto_id.present? && should_send_updates_to?('gusto')
      send_updates_to_gusto()
    end

    if user.lattice_id.present? && should_send_updates_to?('lattice')
      send_updates_to_lattice()
    end

    if user.paychex_id.present? && should_send_updates_to?('paychex')
      send_updates_to_paychex()
    end

    if user.peakon_id.present? && should_send_updates_to?('peakon')
      send_updates_to_peakon()
    end

    if user.paylocity_id.present? && should_send_updates_to?('paylocity')
      send_updates_to_paylocity()
    end

    if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| @company.integration_types.include?(api_name) }.present? && (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?) && !user.super_user
      send_updates_to_adp()
    end

    if !user.super_user && !user.incomplete? && should_send_updates_to?('kallidus_learn')
      send_updates_to_kallidus_learn()
    end
  end

  def send_updates_to_bamboo
    if integration_custom_fields.blank?
      allowed_changes = ['preferred_name', 'personal_email', 'last_name', 'first_name', 'email', 'start_date', 'team_id', 'location_id', 'title', 'manager_id']
      should_send_job_information_to_bamboo = true

      user_updated_changes.try(:each) do |key|
        if allowed_changes.include?(key.downcase)
          if ['team_id', 'location_id', 'title', 'manager_id'].include?(key.downcase) && should_send_job_information_to_bamboo
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(user, "Job Information")  
            should_send_job_information_to_bamboo = false
            next
          end
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(user, key)
        end
      end
    else
      integration_custom_fields.try(:each) do |key, value|
        ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(user, value)
      end
    end
  end

  def send_updates_to_one_login
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'preferred_name', 'email', 'start_date', 'personal_email', 'title', 'team_id', 'location_id', 'manager_id']
        
      user_updated_changes.try(:each) do |key|
        attributes.push(key) if allowed_changes.include?(key.downcase)
      end
      ::SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob.perform_later(user.id, attributes) if attributes.present?
    else
      integration_custom_fields.try(:each) do |key, value|
        next unless ['mobile phone number', 'employment status'].include?(value.downcase)
        ::SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob.perform_later(user.id, [value])
      end
    end
  end

  def send_updates_to_workday
    return if user.workday_id.blank?

    update_workday_user_job = HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob
    updated_fields = integration_custom_fields.blank? ? workday_allowed_changes : integration_custom_fields.values
    update_workday_user_job.perform_later(user.id, updated_fields) if updated_fields.present?
  end

  def send_updates_to_namely
    ::HrisIntegrations::Namely::UpdateNamelyUserFromSaplingJob.perform_async(user.id)
  end

  def send_updates_to_xero
    if integration_custom_fields.blank?
      allowed_changes = ['first_name', 'last_name', 'start_date', 'personal_email', 'title']
      should_send_name_to_xero = true
      user_updated_changes.try(:each) do |key|
        if allowed_changes.include?(key.downcase)
          if ['first_name', 'last_name'].include?(key.downcase) && should_send_name_to_xero
            SendUpdatedEmployeeToXeroJob.perform_later(user, ["first_name","last_name"])
            should_send_name_to_xero = false
            next
          elsif key.downcase == 'personal_email'
            key = key.gsub("_", " ").titleize
          elsif key.downcase == 'title'
            key = 'Job Title'
          end
          SendUpdatedEmployeeToXeroJob.perform_later(user, [key]) unless ['first_name', 'last_name'].include?(key.downcase)
        end
      end
    else
      integration_custom_fields.try(:each) do |key, value|
        SendUpdatedEmployeeToXeroJob.perform_later(user, [value])
      end
    end
  end
  
  def send_updates_to_okta
    if integration_custom_fields.blank?
      allowed_changes = ['first_name', 'last_name', 'preferred_name', 'email', 'personal_email', 'title', 'manager_id', 'team_id']
        
      user_updated_changes.try(:each) do |key|
        if allowed_changes.include?(key.downcase)
          Okta::UpdateEmployeeInOktaJob.perform_async(user.id)
          break
        end
      end
    else
      integration_custom_fields.try(:each) do |key, value|
        Okta::UpdateEmployeeInOktaJob.perform_async(user.id) if Integration.okta_custom_fields(company.id).include?(value)
      end
    end
  end

  def send_updates_to_gsuite
    if integration_custom_fields.blank?
      allowed_changes = ['first_name', 'last_name', 'preferred_name']
        
      user_updated_changes.try(:each) do |key|
        if allowed_changes.include?(key.downcase)
          ::SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob.perform_later(user.id)
          break
        end
      end
    elsif company.google_groups_feature_flag.present?
      integration_custom_fields.try(:each) do |key, value|
        ::SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob.perform_later(user.id, true) if value.titleize == 'Google Organization Unit'
      end
    end
  end

  def send_updates_to_adfs
    if integration_custom_fields.blank?
      allowed_changes = ['first_name', 'last_name', 'preferred_name', 'email', 'start_date', 'title', 'location_id', 'manager_id', 'team_id']
      should_send_display_name_to_adfs = false

      user_updated_changes.try(:each) do |key|
        if allowed_changes.include?(key.downcase)
          should_send_display_name_to_adfs = true
          ::SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.perform_async(user.id, [key.gsub("_", " ").downcase])
        end
      end

      ::SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.perform_async(user.id, ['display name']) if should_send_display_name_to_adfs
    else
      integration_custom_fields.try(:each) do |key, value|
        ::SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.perform_async(user.id, [value]) if value.downcase == 'mobile phone number'
      end
    end
  end  

  def send_updates_to_learn_upon
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'email', 'state']

      user_updated_changes.try(:each) do |key|
        attributes.push(key.gsub('_', ' ')) if allowed_changes.include?(key.downcase)
      end
      ::LearningDevelopmentIntegrations::LearnUpon::UpdateLearnUponUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end
  end

  def send_updates_to_lessonly
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'preferred_name', 'email', 'start_date', 'title', 'team_id', 'location_id', 'manager_id']

      user_updated_changes.try(:each) do |key|
        if (allowed_changes.include? key.downcase)
          if ['first_name', 'last_name', 'preferred_name'].include?(key.downcase)
            attributes.push('username')
          else
            attributes.push(key.gsub('_', ' '))           
          end
        end
      end
      ::LearningDevelopmentIntegrations::Lessonly::UpdateLessonlyUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes.uniq}) if attributes.uniq.present?
    end
  end

  def send_updates_to_deputy
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'start_date', 'email', 'location_id']

      user_updated_changes.try(:each) do |key|
        attributes.push(key.gsub('_', ' ')) if allowed_changes.include?(key.downcase)
      end
      ::HrisIntegrations::Deputy::UpdateDeputyUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    else
      ::HrisIntegrations::Deputy::UpdateDeputyUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: integration_custom_fields.values})
    end
  end

  def send_updates_to_trinet
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'start_date', 'email', 'manager_id', 'team_id', 'title']

      user_updated_changes.try(:each) do |key|
        attributes.push(key.gsub('_', ' ')) if allowed_changes.include?(key.downcase)
      end
      ::HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    else
      integration_custom_fields.try(:each) do |key, value|
        next unless ['flsa status', 'standard hours per week', 'job duties', 'workers comp code', 'gender', 'race/ethnicity', 'date of birth'].include?(value.downcase)
        ::HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: [value.downcase]})
      end
    end
  end

  def send_updates_to_fifteen_five
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'email', 'title', 'team_id', 'location_id', 'manager_id']

      user_updated_changes.try(:each) do |key|
        if allowed_changes.include?(key.downcase)
          attributes.push(key) 
          break
        end
      end
      ::PerformanceIntegrations::FifteenFive::UpdateFifteenFiveUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id}) if attributes.present?
    end
  end
  
  def send_updates_to_gusto
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'email', 'personal_email', 'start_date', 'title']

      user_updated_changes.try(:each) do |key|
        attributes.push(key.gsub('_', ' ')) if allowed_changes.include?(key.downcase)
      end
      ::HrisIntegrations::Gusto::UpdateGustoUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    else
      integration_custom_fields.try(:each) do |key, value|
        ::HrisIntegrations::Gusto::UpdateGustoUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: [value.downcase]})
      end
    end
  end

  def send_updates_to_lattice
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'preferred_name', 'last_name', 'email', 'start_date', 'title', 'manager_id', 'state']

      user_updated_changes.try(:each) do |key|
        if allowed_changes.include?(key.downcase)
          attributes.push(key) 
          break
        end
      end
      ::PerformanceIntegrations::Lattice::UpdateLatticeUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id}) if attributes.present?
    else
      integration_custom_fields.try(:each) do |key, value|
        next unless ['gender', 'date of birth', 'mobile phone number'].include?(value.downcase)
        ::PerformanceIntegrations::Lattice::UpdateLatticeUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id})
      end
    end
  end

  def send_updates_to_paychex
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'preferred_name', 'start_date', 'title', 'location_id', 'manager_id']

      user_updated_changes.try(:each) do |key|
        attributes.push(key.gsub('_', ' ')) if allowed_changes.include?(key.downcase)
      end
      ::HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob.perform_async(user.id, attributes) if attributes.present?
    else
      integration_custom_fields.try(:each) do |key, value|
        next unless ['middle name', 'tax', 'employment status', 'exemption type', 'race/ethnicity', 'date of birth', 'gender'].include?(value.downcase)
        ::HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob.perform_async(user.id, [value.downcase])
      end
    end
  end

  def send_updates_to_peakon
    if integration_custom_fields.blank?
      allowed_changes = ['first_name', 'last_name', 'email', 'start_date', 'state', 'title', 'team_id', 'location_id', 'manager_id']

      user_updated_changes.try(:each) do |key|
        ::PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attribute: key.gsub('_', ' ')}) if allowed_changes.include?(key.downcase)
      end
    else
      integration_custom_fields.try(:each) do |key, value|
        next unless ['mobile phone number', 'employment status', 'gender', 'date of birth'].include?(value.downcase)
        ::PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attribute: value.downcase})
      end
    end
  end

  def send_updates_to_paylocity
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'preferred_name', 'email', 'personal_email', 'title', 'manager_id', 'state']

      user_updated_changes.try(:each) do |key|
        key = 'status' if key.downcase.eql?('state')
        attributes.push(key.gsub('_', ' ')) if allowed_changes.include?(key.downcase)
      end
      ::HrisIntegrations::Paylocity::UpdatePaylocityUserFromSaplingJob.perform_async(user.id, attributes.uniq) if attributes.present?
    else
      integration_custom_fields.try(:each) do |key, value|
        next unless ['mobile phone number', 'home phone number', 'gender', 'social security number', 'federal marital status', 'home address', 'date of birth', 'ethnicity', 'middle name', 'baserate', 'salary', 'pay frequency', 'pay type', 'cost center 1', 'cost center 2', 'cost center 3'].include?(value.downcase)
        attribute = value.downcase == 'home address' ? ['line 1', 'line 2', 'zip', 'city', 'state'] : [value.downcase]
        ::HrisIntegrations::Paylocity::UpdatePaylocityUserFromSaplingJob.perform_async(user.id, attribute)
      end
    end
  end

  def send_updates_to_adp
    if integration_custom_fields.blank?
      allowed_changes = ['preferred_name', 'first_name', 'last_name', 'email', 'personal_email', 'title', 'manager_id']

      user_updated_changes.try(:each) do |key|
        key = 'Job Title' if key.downcase.eql?('title')
        SendUpdatedEmployeeToAdpWorkforceNowJob.perform_later(user.id, key.gsub("_", " ").titleize, nil, user[key].to_s) if allowed_changes.include?(key.downcase)
      end
    else
      integration_custom_fields.try(:each) do |key, value|
        SendUpdatedEmployeeToAdpWorkforceNowJob.perform_later(user.id, value, key)
      end
    end
  end

  def send_updates_to_kallidus_learn
    if integration_custom_fields.blank?
      attributes = []
      allowed_changes = ['first_name', 'last_name', 'email', 'start_date', 'preferred_name', 'title', 'team id', 'location id', 'manager id']

      user_updated_changes.try(:each) do |key|
        attributes.push(key.gsub('_', ' ')) if allowed_changes.include?(key.downcase)
      end
      attributes.push('user name') if (attributes & ['first_name', 'last_name', 'preferred_name']).any?
      ::LearningDevelopmentIntegrations::Kallidus::UpdateKallidusUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes.uniq}) if attributes.present?
    else
      ::LearningDevelopmentIntegrations::Kallidus::UpdateKallidusUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: integration_custom_fields.values})
    end
  end

  def apply_to_location?(filters)
    location_ids = filters['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filters)
    team_ids = filters['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filters)
    employee_types = filters['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end

  def is_integration_applied?(integration)
    return unless integration.filters.present?
    apply_to_location?(integration.filters) && apply_to_team?(integration.filters) && apply_to_employee_type?(integration.filters)
  end

  def should_send_updates_to?(integration_name)
    integrations = company.integration_instances.where(api_identifier: integration_name, state: :active)
    send_updates = false

    integrations.find_each do |integration|
      if is_integration_applied?(integration)
        send_updates = true
        break
      end
    end

    send_updates
  end

  def send_to_integration?(user, company)
    flag = true
    if(company.integration_type == 'paylocity' || company.integration_type == 'adp_wfn_us' || company.integration_type == 'adp_wfn_can'|| company.integration_type == 'adp_wfn_us_and_can')
      filters = company.integrations.where(api_name: ["adp_wfn_us", "adp_wfn_can", "adp_wfn_us_and_can", "paylocity"]).pluck(:meta).first
      flag = false if filters['location_id'] && !filters['location_id'].first.blank? && !filters['location_id'].include?("all") && filters['location_id'].exclude?(user.location_id)
      flag = false if filters['team_id'] && !filters['team_id'].first.blank? && !filters['team_id'].include?("all") && filters['team_id'].exclude?(user.team_id)
      flag = false if filters['employee_type'] && !filters['employee_type'].first.blank? && !filters['employee_type'].include?("all") && filters['employee_type'].exclude?(user.get_custom_field_value_text("Employment Status"))
    end
    flag
  end

  def workday_allowed_changes
    allowed_fields = %w[first_name last_name preferred_name email personal_email title]
    (user_updated_changes.map(&:downcase) & allowed_fields).map { |field_name| field_name.gsub('_', ' ') }
  end
end
