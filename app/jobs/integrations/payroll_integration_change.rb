module Integrations
  class PayrollIntegrationChange
    include Sidekiq::Worker
    sidekiq_options queue: :manage_custom_field_data_migration, retry: false, backtrace: true

    def perform(company_id, api_identifier, is_integration_updated = true)
      company = Company.find_by_id(company_id)
      return unless company.present?

      case api_identifier
      when 'paylocity'
        service = IntegrationsService::Paylocity.new(company)
        service.manage_phone_data_migration_on_integration_change
        service.manage_profile_setup_on_integration_change
      when 'namely'
        integration = ::IntegrationsService::Namely.new(company)
        if is_integration_updated
          integration.manage_profile_setup_on_integration_change
          integration.update_home_group
        end
        integration.update_sapling_department_and_locations
        integration.update_sapling_Custom_groups if company.subdomain.eql?('cruise')
        integration.fetch_users
      when 'workday'
        IntegrationsService::Workday.call(company, 'create_custom_fields')
        HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob.perform_async(company.id, true)
      when 'bamboo_hr'
        integration = company.get_integration(api_identifier)
        service = IntegrationsService::Bamboo.new(company)
        service.manage_profile_setup_on_integration_change
        service.manage_phone_data_migration_on_integration_change
        service.manage_fields_and_groups_on_integration_change(integration)
      when 'adp_wfn_us', 'adp_wfn_can'
        integration_type = company.get_integration(api_identifier)
        integration = ::IntegrationsService::AdpWorkforceNow.new(company)
        integration.manage_profile_setup_on_integration_change
        integration.manage_phone_data_migration_on_integration_change
        integration.manage_fields_and_groups_setup_on_integration_change(integration_type)
      end
    end

  end
end
