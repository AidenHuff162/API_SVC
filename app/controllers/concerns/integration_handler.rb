module IntegrationHandler
  extend ActiveSupport::Concern

  def manage_okta_updates(user, params)
    okta_integration = user.company.integration_instances.find_by(api_identifier: 'okta', state: :active)
    return unless user.okta_id.present? && okta_integration.present? && okta_integration.enable_update_profile  && should_send_okta_update?(user, params)
    Okta::UpdateEmployeeInOktaJob.perform_async(user.id)
  end

  def manage_adfs_productivity_update(user, params, is_custom = false)
    return unless user.active_directory_object_id.present?
    
    if is_custom.blank?
      attributes = []

      ['first_name', 'last_name', 'preferred_name', 'title', 'location_id', 'manager_id', 'team_id'].each do |key|
        if (key != 'start_date' && params[key.to_sym] != user.attributes[key]) || (key == 'start_date' && params[key.to_sym].to_date.strftime("%Y-%m-%d").to_s != user.attributes[key].to_s)
          attributes.push(['first name', 'last name', 'preferred name', 'start date', 'display name', 'title', 'team', 'location'])
          break
        end
      end

      attributes.push(['email']) if params[:email].present? && params[:email].to_s != user.email.to_s
    else
      if ['mobile phone number'].include?(params[0].downcase)
        attributes = [params]
      end
    end

    attributes.try(:each) do |attribute|
      ::SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.perform_async(user.id, attribute)
    end
  end

  def manage_one_login_updates(user, params, is_custom = false)
    attributes = []

    if is_custom.blank?
      ['first_name', 'last_name', 'preferred_name', 'email', 'title', 'team_id', 'start_date', 'location_id', 'manager_id', 'personal_email'].each do |key|
        attributes.push(key) if is_non_custom_data_changed?(key, params, user.attributes)
      end 
    else
      if ['mobile phone number', 'employment status'].include?(params.downcase)
        attributes = [params.downcase]
      end
    end
    ::SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob.perform_later(user.id, attributes)
  end
  
  def manage_gsuite_update(user, company, params)
    return unless company.get_gsuite_account_info.present? && (company.subdomain == 'warbyparker' || Rails.env.staging?)
    
    if !user.incomplete? && ((params.key?(:preferred_name) && user.preferred_name.to_s != params[:preferred_name].to_s) || 
      (params[:last_name] && user.last_name != params[:last_name]) || 
      (user.preferred_name.blank? && params[:first_name] && user.first_name != params[:first_name]) || params.key?(:google_groups))
      ::SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob.perform_later(user.id, params.key?(:google_groups))
    end
  end 

  private

  def should_send_okta_update?(user, params)  
    ['first_name', 'last_name', 'preferred_name', 'email', 'personal_email', 'title', 'manager_id', 'team_id'].each do |key| 
      return true if params[key.to_sym] != user.attributes[key]   
    end 
    return false  
  end

  def is_non_custom_data_changed?(key, params, user_attributes)
    (key != 'start_date' && params[key.to_sym] != user_attributes[key]) || (key == 'start_date' && params[key.to_sym].to_date.strftime("%Y-%m-%d").to_s != user_attributes[key].to_s)
  end
end
