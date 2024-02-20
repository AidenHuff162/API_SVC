namespace :manage_asana_integration do
  desc 'Create Asana integration inventory and configurations'
  task asana: :environment do

    puts 'Creating asana inventory.'
    attributes = { display_name: 'Asana', status: 2, category: 2, knowledge_base_url: 'https://help.saplingapp.io/en/articles/3933154-asana-integration-guide',
        data_direction: 0, enable_filters: false, enable_test_sync: false, api_identifier: 'asana' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)

    puts 'Creating asana inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Asana Organization ID', field_type: 'text', width: '100', help_text: 'Organization ID', position: 0 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Asana Default Team', field_type: 'text', width: '100', help_text: 'Asana team name', position: 1 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Asana Personal Token', field_type: 'text', width: '100', help_text: 'Personal Token', position: 2 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    puts 'Uploading asana inventory logos.'
    display_image_url =  Rails.root.join('app/assets/images/integration_logos/asana.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url),
    type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = Rails.root.join('app/assets/images/integration_logos/asana.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url),
    type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
  end

    desc 'Migrate Asana Credentials'
  task asana_credentials: :environment do

    puts 'Creating Asana Instance.'
    Integration.where(api_name: 'asana').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1'}

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Asana Organization ID'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.asana_organization_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Asana Default Team'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.asana_default_team, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Asana Personal Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.asana_personal_token, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

      end
    end
    puts 'Completed Asana Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:asana, :asana_credentials]
end