namespace :manage_gsuite_integration do
  desc 'Create G-Suite integration inventory and configurations'
  task gsuite: :environment do

    puts 'Creating G-Suite inventory.'
    attributes = { display_name: 'G Suite Account Provisioning', status: 2, category: 2, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018774377', data_direction: 0, enable_filters: false, api_identifier: 'gsuite', enable_authorization: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)

    puts 'Creating  inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Gsuite Account Url', field_type: 'text', width: '100', help_text: 'Subdomain', position: 0 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'settings', field_name: 'Link Gsuite Personal Email', toggle_context: 'Enable personal email linking', toggle_identifier: 'Link Gsuite Personal Email', width: '100', position: 1 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'settings', field_name: 'Gsuite Auth Credentials Present', toggle_context: 'Gsuite Auth Credentials Present', toggle_identifier: 'Gsuite Auth Credentials Present', width: '100', position: 2, is_visible: false}
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    puts 'Uploading G-Suite inventory logos.'
    display_image_url =  Rails.root.join('app/assets/images/integration_logos/gsuite.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url),
    type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = Rails.root.join('app/assets/images/integration_logos/gmail.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url),
    type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
  end

  desc 'Migrate G-Suite Credentials'
  task gsuite_credentials: :environment do

    puts 'Creating G-Suite Instance.'
    Integration.where(api_name: 'gsuite').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Gsuite Account Url'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.gsuite_account_url, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Link Gsuite Personal Email'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.link_gsuite_personal_email, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Gsuite Auth Credentials Present'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.gsuite_auth_credentials_present, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed G-Suite Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:gsuite, :gsuite_credentials]
end