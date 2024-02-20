namespace :manage_slack_integration do
  desc 'Create Slack integration inventory and configurations'
  task slack: :environment do

    puts 'Creating Slack inventory.'
    attributes = { display_name: 'Slack', status: 2, category: 2, api_identifier: 'slack_communication', knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018812798', data_direction: 0, enable_filters: false, enable_test_sync: false }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)

    puts 'Creating Slack inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Webhook Url', field_type: 'text', width: '100',help_text: 'Slack Webhook URL', position: 0 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Channel', field_type: 'text', width: '100', help_text: 'Channel', position: 1 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name]).first_or_create(attributes)

    puts 'Uploading Slack inventory logos.'
    display_image_url =  Rails.root.join('app/assets/images/integration_logos/slack.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = Rails.root.join('app/assets/images/integration_logos/slack.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
  end

  desc 'Migrate Slack Credentials'
  task slack_credentials: :environment do

    puts 'Creating slack_credentials'
    Integration.where(api_name: 'slack_communication').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
      company_id: integration.company_id, name: 'Instance No.1'}

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Webhook Url'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.webhook_url, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Channel'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.channel, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
  end

  desc 'Execute all inventories tasks'
  task all: [:slack, :slack_credentials]
end
