namespace :manage_bswift_integration do
  desc 'Create bswift integration inventory and configurations'
  task bswift: :environment do

    puts 'Creating bswift inventory.'
    attributes = { display_name: 'BSwift', status: 2, category: 8,
                    knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018908358',
                    data_direction: 0, enable_filters: true, enable_test_sync: false, api_identifier: 'bswift' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)

    puts 'Creating bswift inventory configurations.'
    attributes = { category: 'settings', field_name: 'Bswift auto enroll', toggle_context:'Enable Bswift auto enroll',
                    toggle_identifier: 'Bswift auto enroll', width: '100', help_text: 'Bswift auto enroll', position: 1, is_required: false}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift benefit class code', field_type: 'text',
                    width: '100', is_encrypted: false, help_text: 'Bswift benefit class code', position: 2, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift group number', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Bswift group number', position: 3, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift hours per week', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Bswift hours per week', position: 4, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift relation', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Bswift relation', position: 5, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift hostname', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Bswift hostname', position: 6, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift username', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Bswift username', position: 7, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift password', field_type: 'text',
                    width: '100',is_encrypted: true, help_text: 'Bswift password', position: 8, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Bswift remote path', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Bswift remote path', position: 9, is_required: false }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    puts 'Uploading bswift inventory logos.'
    display_image_url =  Rails.root.join('app/assets/images/integration_logos/bswift_logo.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url),
                        type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = Rails.root.join('app/assets/images/integration_logos/bswift_logo.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url),
                        type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
  end


  desc 'Migrate bswift Credentials'
  task bswift_credentials: :environment do

    puts 'Creating bswift Instance.'
    Integration.where(api_name: 'bswift').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: {"location_id"=>["all"], "team_id"=>["all"], "employee_type"=>["all"]}, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', skip_callback: true }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Bswift auto enroll'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_auto_enroll, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift benefit class code'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_benefit_class_code, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift group number'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_group_number, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift hours per week'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_hours_per_week, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift relation'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_relation, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift hostname'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_hostname, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift username'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_username, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift password'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_password, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Bswift remote path'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.bswift_remote_path, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed bswift Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:bswift, :bswift_credentials]

  desc 'Update Bswift category to benefits'
  task update_bswift_category: :environment do
    puts 'Updating bswift category'
    IntegrationInventory.find_by(api_identifier: 'bswift')&.update_column(:category, 'benefits')
    puts 'Successfully Completed bswift category updation.'
  end
end
