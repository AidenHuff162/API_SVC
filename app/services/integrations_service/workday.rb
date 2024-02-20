class IntegrationsService::Workday < ApplicationService
  include HrisIntegrationsService::Workday::Logs

  attr_reader :company, :action

  def initialize(company, action)
    @company = company
    @action = action
  end

  def call
    begin
      send(action)
    rescue Exception => @error
      error_log("Unable to perform '#{action}' for #{company.name}")
    end
  end

  private

  def create_custom_fields
    custom_fields_mapping.each do |_, value|
      field = CustomField.get_custom_field(company, value[:name])
      next if field.present?

      custom_field = company.custom_fields.create(
        name: value[:name],
        section: CustomField.sections[:private_info],
        field_type: CustomField.field_types[value[:type]],
        collect_from: CustomField.collect_froms[:new_hire],
        display_location: CustomField.display_locations[:onboarding]
      )
      update_custom_fields(custom_field)
      create_custom_field_options(custom_field.name)
      create_sub_custom_fields(custom_field)
    end
    success_log("Created Workday custom fields for #{company.name}", custom_fields_mapping.keys)
  end

  def custom_fields_mapping
    {
      citizenship_status: { name: 'Citizenship Status', type: :mcq },
      citizenship_country: { name: 'Citizenship Country', type: :mcq },
      citizenship_type: { name: 'Citizenship Type', type: :mcq },
      company_entity: { name: 'Company/Entity', type: :mcq },
      cost_center: { name: 'Cost Center', type: :mcq },
      date_of_birth: { name: 'Date Of Birth', type: :date },
      disability: { name: 'Disability', type: :mcq }, # type: :relational
      # division: { name: 'Division', type: :mcq },
      ethnicity: { name: 'Race/Ethnicity', type: :mcq },
      gender: { name: 'Gender', type: :mcq },
      marital_status: { name: 'Federal Marital Status', type: :mcq },
      military_service: { name: 'Military Service', type: :mcq },
      # pronoun: { name: 'Pronoun', type: :mcq },
      national_id: { name: 'National ID', type: :national_identifier },
      # sub_division: { name: 'Sub Division', type: :mcq },
      vertical: { name: 'Vertical', type: :mcq },
      workday_termination_reason: { name: 'Workday Termination Reason', type: :mcq },
      middle_name: { name: 'Middle Name', type: :short_text },
      # other_last_names_used: { name: 'Other Last Names Used', type: :short_text },
      # i_9_citizenship_status: { name: 'I-9 Citizenship Status', type: :mcq },
      # permanent_resident: { name: 'Permanent Resident or Alien Number/USCIS Number', type: :short_text },
      # alien_expiration_date: { name: 'Alien Expiration Date', type: :date },
      # foreign_passport_country: { name: 'Alien Foreign Passport Country of Issuance', type: :mcq },
      # foreign_passport_number: { name: 'Foreign Passport Number', type: :short_text },
      # form_i_94_admission_number: { name: 'Form I-94 Admission Number', type: :short_text },
      shipping_address: { name: 'Shipping Address (For packages/Swag Items)', type: :address },
      nationality: { name: 'Nationality', type: :mcq }
    }
  end

  def create_custom_field_options(custom_field_name)
    case custom_field_name
    when 'Alien Foreign Passport Country of Issuance', 'Nationality'
      Country.pluck(:name).each { |country_name| CustomFieldOption.create_custom_field_option(company, custom_field_name, country_name) }
    when 'Citizenship Type'
      CustomFieldOption.create_custom_field_option(company, custom_field_name, 'Not Applicable')
    end
  end

  def create_sub_custom_fields(custom_field)
    sub_custom_field_names = case custom_field.name
                             when 'Shipping Address (For packages/Swag Items)'
                               sub_custom_field_names_hash[:address]
                             when 'National ID'
                               sub_custom_field_names_hash[:national_id]
                             # when 'Disability'
                             #   sub_custom_field_names_hash[:disability]
                             else
                               []
                             end
    sub_custom_field_names.each { |field_name| custom_field.sub_custom_fields.create(name: field_name, field_type: :short_text, help_text: field_name) }
  end

  def update_custom_fields(custom_field)
    params = case custom_field.name
             when 'Cost Center'
               { custom_table_id: CustomTable.role_information(company.id)&.id, integration_group: 'custom_group' }
             when 'Workday Termination Reason'
               { display_location: CustomField.display_locations[:offboarding] }
             when 'I-9 Citizenship Status'
               { help_text: 'I attest, under penalty of perjury, that I am (select one of the options)' }
             end
    custom_field.update(params) if params.present?
  end

  def sub_custom_field_names_hash
    {
      address: ['Line 1', 'Line 2', 'City', 'Country', 'State', 'Zip'],
      national_id: ['ID Country', 'ID Type', 'ID Number'],
      disability: ['Disability Status', 'Disability Type']
    }
  end

  # def nullify_unsync_workday_ids
  #   filtered_users = IntegrationsService::Filters.call(company.users.with_workday, company.get_integration('workday'))
  #   company.users.with_workday.where.not(id: filtered_users.select(&:id)).update_all(workday_id: nil)
  # end

end
