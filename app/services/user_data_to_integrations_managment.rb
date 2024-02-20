class UserDataToIntegrationsManagment
  include ADPHandler, IntegrationHandler
  include IntegrationFilter
  include WebhookHandler
  include XeroIntegrationUpdation

  def send_user_updates_to_integrations(user, params, company)
    updated_user = company.users.find_by_id(user.id)
    integration_type = company.integration_type
    auth_type = company.authentication_type

    if company.integration_types.include?("bamboo_hr") && updated_user.bamboo_id.present?
      if (params[:manager_id] && user.manager_id != params[:manager_id]) ||
        (params[:title] && user.title != params[:title]) ||
        (params[:team_id] && user.team_id != params[:team_id]) ||
        (params[:location_id] && user.location_id != params[:location_id])
        ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Job Information")
      end
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "preferred_name") if params[:preferred_name] && user.preferred_name != params[:preferred_name]
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Employment Status") if params[:employee_type] && user.employee_type != params[:employee_type]
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "personal_email") if params[:personal_email] && user.personal_email != params[:personal_email]
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "last_name") if params[:last_name] && user.last_name != params[:last_name]
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "first_name") if params[:first_name] && user.first_name != params[:first_name]
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "email") if params[:email] && user.email != params[:email]
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Profile Photo") if params[:is_profile_image_updated].present?
      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "start_date") if params[:start_date] && params[:start_date].to_date.strftime("%Y-%m-%d") != user.start_date.to_s
    end

    if auth_type == "one_login" && updated_user.one_login_id.present?
      manage_one_login_updates(user, params)
    end

    if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| company.integration_types.include?(api_name) }.present?
      if params[:personal_email] && user.personal_email != params[:personal_email]
        update_adp_profile(user.id, 'Personal Email', nil, params[:personal_email]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end
      if params[:email] && user.email != params[:email]
        update_adp_profile(user.id, 'Email', nil, params[:email]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end
      if params[:preferred_name] && user.preferred_name != params[:preferred_name]
        update_adp_profile(user.id, 'Preferred Name', nil, params[:preferred_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end
      if params[:first_name] && user.first_name != params[:first_name]
        update_adp_profile(user.id, 'First Name', nil, params[:first_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end
      if params[:last_name] && user.last_name != params[:last_name]
        update_adp_profile(user.id, 'Last Name', nil, params[:last_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end
      if params[:title] && user.title != params[:title]
        update_adp_profile(user.id, 'Job Title', nil, params[:title]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end
      if params[:manager_id] && user.manager_id != params[:manager_id]
        update_adp_profile(user.id, 'Manager Id', nil, nil) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end
    end

    if integration_type == "xero" && user.xero_id.present?
      send_to_xero_integration user, params
    end

    manage_gsuite_update(user, company, params)

    if company.can_provision_adfs? && user.active_directory_object_id.present?
      manage_adfs_productivity_update(user, params)
    end

    manage_okta_updates(user, params)

    ::IntegrationsService::UserIntegrationOperationsService.new(user).perform('update', params)
  end
end