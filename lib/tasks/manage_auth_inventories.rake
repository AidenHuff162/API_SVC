namespace :manage_auth_integration do
  task google_auth: :environment do  

    puts 'Creating Google Auth inventory.'
    attributes = { display_name: 'Google Auth', status: 2, category: 3, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018774377',
      data_direction: 0, enable_filters: false, api_identifier: 'google_auth' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Google Auth inventory.'

    # puts 'Creating Google Auth inventory configurations.'
    # attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.15five.com',
    #   width: '100', help_text: 'Company URL', position: 1 }
    # integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    # attributes = { category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 2 }
    # integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    # attributes = {category: 'settings', toggle_context: 'When a team member is deleted in Sapling, delete their 15Five account', toggle_identifier: 'can delete profile', position: 3 }
    # integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created Google Auth inventory configurations.'

    puts 'Uploading Google Auth inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/gsuite-logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 

    # dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/gsuite-logo.png"
    # UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
    #   type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    # puts 'Uploaded Google Auth inventory logos.'
  end
  
  desc 'Migrate Google Auth Credentials'
  task google_auth_credentials: :environment do

    puts 'Creating Google Auth Instance.'
    Integration.where(api_name: 'google_auth').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      # if instance.present?
      #   subdomain = 'Subdomain'
      #   configuration = integration_inventory.integration_configurations.find_by(field_name: subdomain)
      #   attributes = { value: integration.subdomain, name: subdomain, integration_configuration_id: configuration.id }
      #   instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

      #   access_token = 'Access Token'
      #   configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
      #   attributes = { value: integration.access_token, name: access_token, integration_configuration_id: configuration.id }
      #   instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
      #   can_delete_profile = 'can delete profile'
      #   configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
      #   attributes = { value: integration.can_delete_profile, name: can_delete_profile, integration_configuration_id: configuration.id }
      #   instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      # end
    end
    puts 'Completed Google Auth Instance creation.'
  end


  task onelogin: :environment do  
    
    puts 'Creating OneLogin inventory.'
    attributes = { display_name: 'OneLogin', status: 2, category: 3, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018774597',
      data_direction: 0, enable_filters: false, api_identifier: 'one_login' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    
    puts 'Created OneLogin inventory.'
    attributes = { category: 'credentials', field_name: 'Identity Provider SSO Url', field_type: 'text', width: '100', help_text: 'Identity Provider SSO Url', position: 1}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'SAML Certificate', field_type: 'text', width: '100', help_text: 'SAML Certificate', position: 2}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'SAML Metadata Endpoint', field_type: 'text', width: '100', help_text: 'SAML Metadata Endpoint', position: 3, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Client Secret', field_type: 'text', width: '100', help_text: 'Client Secret', position: 4, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'Client ID', field_type: 'text', width: '100', help_text: 'Client ID', position: 5, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
 
    options = [{label: 'US', value: 'US'}, {label: 'EU', value: 'EU'}]
    attributes = {category: 'credentials', field_name: 'Region', field_type: 'dropdown', width: '100', help_text: 'Region', position: 6, dropdown_options: options, is_required: false}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings', toggle_context: 'Provision New Hires directly from Sapling', toggle_identifier: 'Enable Create Profile', position: 7 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'settings', toggle_context: 'When Employee data is changed in Sapling, send these updates to OneLogin', toggle_identifier: 'Enable Update Profile', position: 8 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'settings', toggle_context: 'Sync Preferred Name to First Name', toggle_identifier: 'Sync Preferred Name', position: 8, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    puts 'Created OneLogin inventory configurations.'
    
    puts 'Uploading OneLogin inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/one_login.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/one_login.png"
    UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded OneLogin inventory logos.'
  end

  desc 'Migrate OneLogin Credentials'
  task onelogin_credentials: :environment do

    puts 'Creating OneLogin Instance.'
    Integration.where(api_name: 'one_login').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        access_token = 'Identity Provider SSO Url'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.identity_provider_sso_url, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      
        access_token = 'SAML Certificate'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.saml_certificate, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        access_token = 'SAML Metadata Endpoint'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.saml_metadata_endpoint, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        access_token = 'Client Secret'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.client_secret, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        access_token = 'Client ID'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.client_id, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        access_token = 'Region'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.region, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        can_delete_profile = 'Enable Create Profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
        attributes = { value: integration.enable_create_profile, name: can_delete_profile, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
     
        can_delete_profile = 'Enable Update Profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
        attributes = { value: integration.enable_update_profile, name: can_delete_profile, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
     
        can_delete_profile = 'Sync Preferred Name'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
        attributes = { value: integration.sync_preferred_name, name: can_delete_profile, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed OneLogin Instance creation.'
  end

  task okta: :environment do  
    
    puts 'Creating OKTA inventory.'
    attributes = { display_name: 'OKTA', status: 2, category: 3, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018774557',
      data_direction: 0, enable_filters: false, api_identifier: 'okta' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    
    puts 'Created OKTA inventory.'
    attributes = { category: 'credentials', field_name: 'Identity Provider SSO Url', field_type: 'text', width: '100', help_text: 'Identity Provider SSO Url', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'SAML Certificate', field_type: 'text', width: '100', help_text: 'SAML Certificate', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'SAML Metadata Endpoint', field_type: 'text', width: '100', help_text: 'SAML Metadata Endpoint', position: 3, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Api Key', field_type: 'text', width: '100', help_text: 'Secret Token', position: 4, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)    

    attributes = {category: 'settings', toggle_context: 'Provision New Hires directly from Sapling', toggle_identifier: 'Enable Create Profile', position: 7 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings', toggle_context: 'Sync changes from Sapling to Okta', toggle_identifier: 'Enable Update Profile', position: 8 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    puts 'Created OKTA inventory configurations.'
    
    puts 'Uploading OKTA inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/okta.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/okta.png"
    UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded OKTA inventory logos.'
  end

  desc 'Migrate OKTA Credentials'
  task okta_credentials: :environment do

    puts 'Creating OKTA Instance.'
    Integration.where(api_name: 'okta').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        access_token = 'Identity Provider SSO Url'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.identity_provider_sso_url, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      
        access_token = 'SAML Certificate'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.saml_certificate, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        access_token = 'SAML Metadata Endpoint'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.saml_metadata_endpoint, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        access_token = 'Api Key'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.secret_token, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        can_delete_profile = 'Enable Create Profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
        attributes = { value: integration.enable_create_profile, name: can_delete_profile, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        can_delete_profile = 'Enable Update Profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
        attributes = { value: integration.enable_update_profile, name: can_delete_profile, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

      end
    end
    puts 'Completed OKTA Instance creation.'
  end


  task adfs: :environment do  
    puts 'Creating ADFS inventory.'
    attributes = { display_name: 'ADFS', status: 2, category: 3, knowledge_base_url: '',
      data_direction: 0, enable_filters: false, api_identifier: 'active_directory_federation_services' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    
    puts 'Created ADFS inventory.'
    attributes = { category: 'credentials', field_name: 'Identity Provider SSO Url', field_type: 'text', width: '100', help_text: 'Identity Provider SSO Url', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'SAML Certificate', field_type: 'text', width: '100', help_text: 'SAML Certificate', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created ADFS inventory configurations.'
    
    puts 'Uploading ADFS inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/adfs.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/adfs.png"
    UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded ADFS inventory logos.'
  end

  desc 'Migrate ADFS Credentials'
  task adfs_credentials: :environment do

    puts 'Creating ADFS Instance.'
    Integration.where(api_name: 'active_directory_federation_services').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        access_token = 'Identity Provider SSO Url'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.identity_provider_sso_url, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      
        access_token = 'SAML Certificate'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.saml_certificate, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed ADFS Instance creation.'
  end

  task shibboleth: :environment do  
    puts 'Creating Shibboleth inventory.'
    attributes = { display_name: 'Shibboleth', status: 2, category: 3, knowledge_base_url: '',
    data_direction: 0, enable_filters: false, api_identifier: 'shibboleth' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    
    puts 'Created Shibboleth inventory.'
    attributes = { category: 'credentials', field_name: 'Identity Provider SSO Url', field_type: 'text', width: '100', help_text: 'Identity Provider SSO Url', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'SAML Certificate', field_type: 'text', width: '100', help_text: 'SAML Certificate', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created Shibboleth inventory configurations.'
    
    puts 'Uploading Shibboleth inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/shibboleth.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/shibboleth.png"
    UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Shibboleth inventory logos.'
  end

  desc 'Migrate Shibboleth Credentials'
  task shibboleth_credentials: :environment do

    puts 'Creating Shibboleth Instance.'
    Integration.where(api_name: 'shibboleth').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        access_token = 'Identity Provider SSO Url'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.identity_provider_sso_url, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      
        access_token = 'SAML Certificate'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.saml_certificate, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Shibboleth Instance creation.'
  end

  task ping_id: :environment do  
    puts 'Creating Ping ID inventory.'
    attributes = { display_name: 'Ping ID', status: 2, category: 3, knowledge_base_url: '',
      data_direction: 0, enable_filters: false, api_identifier: 'ping_id' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    
    puts 'Created Ping ID inventory.'
    attributes = { category: 'credentials', field_name: 'Identity Provider SSO Url', field_type: 'text', width: '100', help_text: 'Identity Provider SSO Url', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'SAML Certificate', field_type: 'text', width: '100', help_text: 'SAML Certificate', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created Ping ID inventory configurations.'
    
    puts 'Uploading Ping ID inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/ping_id.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/ping_id.png"
    UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded ADFS inventory logos.'
  end

  desc 'Migrate Ping ID Credentials'
  task ping_id_credentials: :environment do

    puts 'Creating Ping ID Instance.'
    Integration.where(api_name: 'ping_id').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        access_token = 'Identity Provider SSO Url'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.identity_provider_sso_url, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      
        access_token = 'SAML Certificate'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.saml_certificate, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Ping ID Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:google_auth, :google_auth_credentials, :onelogin, :onelogin_credentials, :okta, :okta_credentials, :adfs, :adfs_credentials, :shibboleth, :shibboleth_credentials, :ping_id, :ping_id_credentials]
end