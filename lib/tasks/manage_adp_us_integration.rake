namespace :manage_adp_us_integration do
  
  desc 'Create ADP US integration inventory and configurations'
  task adp_us: :environment do  
    
    puts 'Creating ADP US inventory.'
    attributes = { display_name: 'ADP Workforce Now: United States', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018669837', 
      data_direction: 1, enable_filters: true, api_identifier: 'adp_wfn_us' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created ADP US inventory.'

    puts 'Creating ADP US inventory configurations.'
    attributes = {category: 'credentials', field_name: 'Client ID', field_type: 'text', width: '100', help_text: 'Client ID', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'credentials', field_name: 'Client Secret', field_type: 'text', width: '100', help_text: 'Client Secret', position: 2, is_encrypted: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'credentials', field_name: 'Onboarding Templates', field_type: 'dropdown', width: '100', help_text: 'Onboarding Templates', position: 3, is_visible: false, dropdown_options: {}}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings', field_name: 'Can Export Updation', toggle_context:'Sync Changes from Sapling to ADP', toggle_identifier:'Can Export Updation', width: '100', position: 4}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings' ,field_name: 'Can Import Data', toggle_context:'Sync Changes from ADP to Sapling', toggle_identifier:'Can Import Data', width: '100', position: 5}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings', field_name: 'Enable Company Code', toggle_context:'Enable multiple company codes', toggle_identifier:'Enable Company Code', width: '100', position: 6}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'settings', field_name: 'Enable Tax Type', toggle_context:'Enable multiple tax types', toggle_identifier:'Enable Tax Type', width: '100', position: 7}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    puts 'Created ADP US inventory configurations.'
    
    puts 'Uploading ADP US inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/adp_us.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/adp.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded ADP US inventory logos.'
  end

  desc 'Migrate ADP US Credentials'
  task adp_us_credentials: :environment do

    puts 'Creating ADP US Instance.'
    Integration.where(api_name: 'adp_wfn_us').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { skip_callback: true, api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', synced_at: integration.last_sync }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Client ID'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Client Secret'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_secret, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Onboarding Templates'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { dropdown_options: integration.onboarding_templates, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Can Export Updation'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.can_export_updation, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Can Import Data'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.can_import_data, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Enable Company Code'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.enable_company_code, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Enable Tax Type'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.enable_tax_type, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed ADP US Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:adp_us, :adp_us_credentials]
end