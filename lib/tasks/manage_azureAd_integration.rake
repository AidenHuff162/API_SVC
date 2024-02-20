namespace :manage_azure_integration do
  desc 'Create Azure-AD integration inventory and configurations'
  task azure: :environment do

    puts 'Creating Azure-AD inventory.'
    attributes = { display_name: 'Active Directory Account Provisioning', status: 2, category: 2, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018908658', data_direction: 0, enable_filters: false, api_identifier: 'adfs_productivity', enable_authorization: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)

    puts 'Creating Azure-AD inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'text', width: '100', help_text: 'Subdomain', position: 0 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 1, is_encrypted: true, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'credentials', field_name: 'Expires In', field_type: 'text', width: '100', help_text: 'Expires In', position: 2, is_encrypted: true, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'credentials', field_name: 'Refresh Token', field_type: 'text', width: '100', help_text: 'Refresh Token', position: 3, is_encrypted: true, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'settings', field_name: 'Enable Update Profile', toggle_context: 'Sync changes from Sapling to Active Directory', toggle_identifier: 'Enable Update Profile', width: '100', position: 4 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    puts 'Uploading Azure-AD inventory logos.'
    display_image_url =  Rails.root.join('app/assets/images/integration_logos/azure_ad.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url),
    type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = Rails.root.join('app/assets/images/integration_logos/azure_ad.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url),
    type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
  end

  desc 'Migrate Azure-AD Credentials'
  task azure_credentials: :environment do

    puts 'Creating Azure-AD Instance.'
    Integration.where(api_name: 'adfs_productivity').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Subdomain'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.gsuite_account_url, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.access_token, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'Expires In'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.expires_in, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'Refresh Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.refresh_token, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Enable Update Profile'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.enable_update_profile, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Azure-AD Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:azure, :azure_credentials]
end