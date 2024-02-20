module ADPHandler
  extend ActiveSupport::Concern
  include IntegrationFilter

  def create_adp_profile(user_id)
    user = User.find_by_id(user_id)
    return unless user&.super_user?.blank?

    if user.adp_wfn_us_id.blank? && user.adp_wfn_can_id.blank?
      SendEmployeeToAdpWorkforceNowJob.set(wait: 2.minutes).perform_later(user_id)
    end
  end

  def update_adp_profile(user_id, field_name, field_id=nil, value=nil)
    user = User.find_by_id(user_id)
    return unless user&.super_user?.blank?
    
    SendUpdatedEmployeeToAdpWorkforceNowJob.perform_later(user_id, field_name, field_id, value)
  end

  def fetch_onboarding_templates
    if current_company.integration_types.include?('adp_wfn_us') && current_company.integration_types.exclude?('adp_wfn_can')
      return fetch_templates_from_adp(current_company, 'adp_wfn_us')
    end

    if current_company.integration_types.include?('adp_wfn_can') && current_company.integration_types.exclude?('adp_wfn_us')
     return fetch_templates_from_adp(current_company, 'adp_wfn_can')
    end

    if current_company.integration_types.include?('adp_wfn_us') && current_company.integration_types.include?("adp_wfn_can")
      us_template = fetch_templates_from_adp(current_company, 'adp_wfn_us')
      can_template = fetch_templates_from_adp(current_company, 'adp_wfn_can')

      return us_template.merge(can_template)
    end
  end

  private

  def fetch_templates_from_adp(company, api_name)
    adp_wfn_api = company.integration_instances.where('api_identifier = ? AND state = ?', api_name, 1).take
    return {} unless adp_wfn_api.present?

    ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_wfn_api).sync
    onboarding_templates = adp_wfn_api.integration_credentials.find_by(name: 'Onboarding Templates')&.dropdown_options
    if !company.adp_v2_migration_feature_flag
      enviornment = adp_wfn_api&.api_identifier&.split('_')&.last
      return templates = {
        "#{enviornment}": filter_out_international_templates(onboarding_templates[enviornment], enviornment&.upcase)
      }
    else
      return onboarding_templates || {}
    end
  end

  def filter_out_international_templates(onboarding_templates, enviornment)
    return [] if onboarding_templates.blank?
    supported_onboarding_templates = ['HR + Payroll (System)', 'HR + Payroll + Time (System)', 'HR + Time (System)', 'HR Only (System)', 'Applicant Onboard', 'Applicant Onboard US']
    selected_onboarding_templates = [] 

    onboarding_templates.clone.each do |onboarding_template|
      onboarding_template.clone.each do |k, v|
        name = v.split('-')
        if supported_onboarding_templates.include?(name[0].strip) && 
           ((enviornment == 'US' && (name[name.length-1].strip.downcase == 'us')) || (enviornment == 'CAN' && (name[name.length-1].strip.downcase == 'canada') || Rails.env == 'staging'))
          onboarding_template['template_name'] = onboarding_template.delete(k)
          selected_onboarding_templates.push(onboarding_template)
        end
      end
    end
    selected_onboarding_templates     
  end
  
end
