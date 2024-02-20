class CustomFieldValueToIntegrationsManagment
  include ADPHandler, IntegrationHandler
  include WebhookHandler

  def send_custom_field_updates_to_integrations(user, field_name, custom_field, company)
    user.reload
    if user.present?
      if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| company.integration_types.include?(api_name) }.present?
        update_adp_profile(user.id, custom_field.name, custom_field.id) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
      end

      ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(user, custom_field.name) if user.bamboo_id.present?

      if company.can_provision_adfs? && user.active_directory_object_id.present?
        manage_adfs_productivity_update(user, [custom_field.name], true)
      end

      if company.authentication_type == 'one_login' && user.one_login_id.present?
        manage_one_login_updates(user, custom_field.name, true)
      end

      Okta::UpdateEmployeeInOktaJob.perform_async(user.id) if user.okta_id.present? && Integration.okta_custom_fields(user.company_id).include?(custom_field.name)

      ::IntegrationsService::UserIntegrationOperationsService.new(user, ['deputy', 'peakon', 'trinet', 'gusto', 'lattice', 'paychex', 'kallidus_learn', 'paylocity', 'namely', 'xero', 'workday'], [], { is_custom: true, name: custom_field.name.downcase } ).perform('update')
      
      manage_gsuite_update(user, company, {google_groups: true}) if company.google_groups_feature_flag.present? && field_name == "Google Organization Unit"
    end
  end
end