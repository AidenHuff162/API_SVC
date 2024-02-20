# manage_workday_integration
namespace :migrations do
  desc 'Creating workday integration'
  task workday: :environment do
    puts 'Creating workday inventory.'
    attributes = { display_name: 'Workday', status: 2, category: 1,
                   knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019474117',
                   data_direction: 2, enable_filters: true, enable_test_sync: false, api_identifier: 'workday' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)

    puts 'Creating workday integration configurations.'
    attributes = { category: 'credentials', field_name: 'User Name', field_type: 'text',
                   width: '100', is_encrypted: false, help_text: 'User Name', position: 1, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Password', field_type: 'text',
                   width: '100', is_encrypted: true, help_text: 'Password', position: 2, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Human Resource WSDL', field_type: 'text',
                   width: '100', is_encrypted: false, help_text: 'Human resource wsdl', position: 3, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Staffing WSDL', field_type: 'text',
                   width: '100', is_encrypted: false, help_text: 'Human resource wsdl', position: 4, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Document Category WID', field_type: 'text',
                   width: '100', is_encrypted: false, help_text: 'Document Category WID', position: 5, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Tenant Name', field_type: 'text',
                   width: '100', is_encrypted: false, help_text: 'Tenant Name', position: 6, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Organization Type for Department', field_type: 'text',
                   width: '100', is_encrypted: false, help_text: 'Organization Type i.e. Cost Center Hierarchy/Supervisory', position: 6, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)
    attributes = { category: 'credentials', field_name: 'Contingent Worker Filter', field_type: 'multi_select',
                   width: '100', is_encrypted: false, help_text: 'Contingent Worker Filter', position: 7, is_required: false,
                   dropdown_options: [{ label: 'PEO', value: 'PEO' }, { label: 'Contractor', value: 'Contractor' }, { label: 'Intern', value: 'Intern' }, { label: 'Consultant', value: 'Consultant' }, { label: 'Vendor', value: 'Vendor' }]}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)
    attributes = { category: 'credentials', field_name: 'Employee Worker Filter', field_type: 'multi_select',
                   width: '100', is_encrypted: false, help_text: 'Employee Worker Filter', position: 8, is_required: false,
                   dropdown_options: [{ label: 'Regular', value: 'Regular' }, { label: 'Fixed Term (Fixed Term)', value: 'Fixed_Term' }, { label: 'Intern (Seasonal)', value: 'EMPLOYEE_TYPE-3-3' }]}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
                         .first_or_create(attributes)

    # attributes = {category: 'settings', field_name: 'Sync Contractors', toggle_context: 'Sync Contractors', toggle_identifier: 'Workday Contractors Sync', width: '100', position: 7}
    # integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    # attributes = { category: 'credentials', field_name: 'External Form I-9 Source WID', field_type: 'text',
    #                width: '100', is_encrypted: false, help_text: 'External Form I-9 Source WID', position: 6, is_required: false }
    # integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name])
    #                      .first_or_create(attributes)

    puts 'Uploading workday inventory logos.'
    display_image_url =  Rails.root.join('app/assets/images/integration_logos/workday_logo.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url),
                        type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = Rails.root.join('app/assets/images/integration_logos/workday_logo.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url),
                        type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
  end

  desc 'Migrate Workday Credentials'
  task workday_credentials: :environment do
    puts 'Creating Workday Instance.'

    Integration.where(api_name: 'workday').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: {"location_id"=>["all"], "team_id"=>["all"], "employee_type"=>["all"]}, state: :active,
                     integration_inventory_id: integration_inventory.id, company_id: integration.company_id, name: 'Instance No.1', skip_callback: true }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload
      if instance.present?
        field_name = 'User Name'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.iusername, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Password'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.ipassword, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Human Resource WSDL'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.workday_human_resource_wsdl, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Staffing WSDL'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: nil, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Document Category WID'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: nil, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Tenant Name'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: nil, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Organization Type for Department'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: nil, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        # field_name = 'Sync Contractors'
        # configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        # attributes = { value: nil, name: field_name, integration_configuration_id: configuration.id }
        # instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        # field_name = 'External Form I-9 Source WID'
        # configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        # attributes = { value: nil, name: field_name, integration_configuration_id: configuration.id }
        # instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Workday Instance creation.'
  end

  task set_default_credentials_for_billcom: :environment do
    puts 'Setting up default credentials for billcom'
    begin
      company = Company.find_by_subdomain('billcom')
      integration = company.get_integration('workday')
      integration.integration_credentials.by_name('Contingent Worker Filter').take.update_column(:selected_options, ['PEO'])
      integration.integration_credentials.by_name('Employee Worker Filter').take.update_column(:selected_options, ['Regular', 'Fixed Term (Fixed Term)', 'Intern (Seasonal)'])
      puts 'Set up default credentials for billcom'
    rescue Exception => e
      puts "Failed to run set_default_credentials_for_billcom with: #{e}"
    end
  end

  desc 'Execute all inventories tasks'
  task all: [:workday, :workday_credentials]

end