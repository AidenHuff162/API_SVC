namespace :manage_xero_integration do

  desc 'Create Xero integration inventory and configurations'
  task xero: :environment do  
    
    puts 'Creating Xero inventory.'
    attributes = { display_name: 'Xero', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018908558-Sapling-Xero-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'xero', enable_multiple_instance: true, enable_connect: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Xero inventory.'

    puts 'Creating Xero inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'Company Code', field_type: 'text', width: '100', help_text: 'Company Code', position: 1, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 2, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Refresh Token', field_type: 'text', width: '100', help_text: 'Refresh Token', position: 3, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Expires In', field_type: 'text', width: '100', help_text: 'Expires In', position: 4, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Organization Name', field_type: 'text', width: '100', help_text: 'Organization Name', position: 5, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Subscription Id', field_type: 'text', width: '100', help_text: 'Subscription Id', position: 6, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Payroll Calendar', field_type: 'options', width: '100', help_text: 'Payroll Calendar', position: 7, is_visible: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Employee Group', field_type: 'options', width: '100', help_text: 'Employee Group', position: 8, is_visible: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Pay Template', field_type: 'options', width: '100', help_text: 'Pay Template', position: 9, is_visible: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
   
    puts 'Created Xero inventory configurations.'
    
    puts 'Uploading Xero inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/xero.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/xero.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Xero inventory logos.'
  end

  desc 'Migrate Xero Credentials'
  task xero_credentials: :environment do

    puts 'Creating Xero Instance.'
    Integration.where(api_name: 'xero').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', is_authorized: true, synced_at: integration.last_sync }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      
      if instance.present?
        field_name = 'Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.access_token, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Refresh Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.refresh_token, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Expires In'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.expires_in, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Payroll Calendar'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.payroll_calendar_id, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Employee Group'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.employee_group_name, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Pay Template'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.earnings_rate_id, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Organization Name'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.organization_name, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

      end
    end
    puts 'Completed Xero Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:xero, :xero_credentials]
end