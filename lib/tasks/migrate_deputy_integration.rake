namespace :manage_deputy_integration do

  desc 'Create Deputy integration inventory and configurations'
  task deputy: :environment do  
    
    puts 'Creating Deputy inventory.'
    attributes = { display_name: 'Deputy', status: 2, category: 4, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018774337-Sapling-Deputy-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'deputy', enable_authorization: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Deputy inventory.'

    puts 'Creating Deputy inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Client ID', field_type: 'text', width: '100', help_text: 'Client ID', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'Client Secret', field_type: 'text', width: '100', help_text: 'Client Secret', position: 2, is_encrypted: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 3, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Refresh Token', field_type: 'text', width: '100', help_text: 'Refresh Token', position: 4, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Expires In', field_type: 'text', width: '100', help_text: 'Expires In', position: 5, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'text', width: '100', help_text: 'Subdomain', position: 6, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings', toggle_context: 'When a new team member is onboarded in Sapling, send them an invite to Deputy', toggle_identifier: 'Can Invite Profile', position: 7 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings', toggle_context: 'When a team member is offboarded in Sapling, delete their Deputy account in addition to terminating the team member in deputy', toggle_identifier: 'Can Delete Profile', position: 8 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created Deputy inventory configurations.'
    
    puts 'Uploading Deputy inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/display_deputy.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/deputy_dialog_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Deputy inventory logos.'
  end

  desc 'Migrate Deputy Credentials'
  task deputy_credentials: :environment do

    puts 'Creating Deputy Instance.'
    Integration.where(api_name: 'deputy').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', is_authorized: true, synced_at: integration.last_sync }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      
      if instance.present?
        field_name = 'Client ID'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Client Secret'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_secret, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

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

        field_name = 'Subdomain'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.subdomain, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'can_invite_profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: field_name)
        attributes = { value: integration.can_invite_profile, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'can_delete_profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: field_name)
        attributes = { value: integration.can_delete_profile, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Deputy Instance creation.'
  end

  desc 'Update Deputy Dialog Logo'
  task update_logo: :environment do
    integration_inventory = IntegrationInventory.find_by(api_identifier: 'deputy')

    if integration_inventory.present?
      integration_inventory.dialog_display_logo&.destroy
      dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/deputy_dialog_logo.png"
      UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
        type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    end
    puts 'Updated Deputy inventory logos.'
  end  

  desc 'Execute all inventories tasks'
  task all: [:deputy, :deputy_credentials]
end