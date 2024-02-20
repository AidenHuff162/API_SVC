# Manage custom section and table fields
class CustomFieldsService
  attr_reader :company

  def initialize(company)
    @company = company
  end

  def is_compensation_table_exists?
    @company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:compensation]).present?
  end

  def is_preference_field_exists?(default_fields, name)
    default_fields.select { |default_field| default_field['name'] == name }.present?
  end

  def find_max_position(section)
    preference_field_position = @company.prefrences['default_fields'].select { |default_field|
      default_field['section'] == CustomField.sections.key(section) }.max_by{ |default_field| default_field['position'] }['position'] rescue 0
    custom_field_position = CustomField.where.not(position: nil).where(section: section, company_id: @company.id).max_by(&:position).try(:position).try(:to_i) || 0

    (preference_field_position && preference_field_position > custom_field_position) ? preference_field_position : custom_field_position
  end

  def update_custom_field(custom_field, params)
    custom_field.update(params)
  end

  def create_custom_field(params)
    @company.custom_fields.create!(params)
  end

  def remove_preference_field(name)
    preferences = @company.prefrences
    default_fields = preferences['default_fields']

    default_fields.delete_if { |default_field| default_field['name'] == name }
    @company.update_column(:prefrences, preferences)
  end

  def create_custom_field_options(custom_field, options)
    return unless options.present?
    options.try(:each) { |option| custom_field.custom_field_options.find_or_initialize_by(option: option).save! }
  end

  def create_sub_custom_fields(custom_field)
    if custom_field.currency?
      custom_field.sub_custom_fields.create(name: 'Currency Type', field_type: SubCustomField.field_types[:short_text], help_text: 'Currency Type')
      custom_field.sub_custom_fields.create(name: 'Currency Value', field_type: SubCustomField.field_types[:number], help_text: 'Currency Value' )
    elsif custom_field.phone?
      custom_field.sub_custom_fields.create(name: 'Country', field_type: SubCustomField.field_types[:short_text], help_text: 'Country')
      custom_field.sub_custom_fields.create(name: 'Area code', field_type: SubCustomField.field_types[:short_text], help_text: 'Area code')
      custom_field.sub_custom_fields.create(name: 'Phone', field_type: SubCustomField.field_types[:short_text], help_text: 'Phone')
    elsif custom_field.tax?
      custom_field.sub_custom_fields.create(name: 'Tax Type', field_type: SubCustomField.field_types[:short_text], help_text: 'Tax Type')
      custom_field.sub_custom_fields.create(name: 'Tax Value', field_type: SubCustomField.field_types[:short_text], help_text: 'Tax Value')
    end
  end

  def should_create_sub_custom_fields?(custom_field)
    custom_field.currency? || custom_field.phone? || custom_field.tax?
  end

  def create_custom_field_if_not_exists(params, options = [], by_field_type = false)
    if by_field_type.present?
      custom_field = @company.custom_fields.where('name ILIKE ? AND field_type = ?', params[:name], params[:field_type]).take
    else
      custom_field = @company.custom_fields.where('name ILIKE ?', params[:name]).take
    end

    if !custom_field.present?
      params.merge!(position: find_max_position(params[:section]) + 1) if !params[:position].present?
      custom_field = create_custom_field(params)
      create_custom_field_options(custom_field, options) if options.present?
      create_sub_custom_fields(custom_field) if should_create_sub_custom_fields?(custom_field)
    else
      create_custom_field_options(custom_field, options) if options.present?
    end

    custom_field
  end

  def create_custom_groups_on_integration_change(params = {})
    return unless params.present?
    if params[:integration_group] == CustomField.integration_groups[:adp_wfn]
      custom_group = CustomField.where(name: params[:name], field_type: params[:field_type], company_id: @company.id).take
    else
      custom_group = CustomField.where(name: params[:name], field_type: params[:field_type], company_id: @company.id).where(deleted_at: nil).take
    end

    if custom_group.present?
      update_custom_field(custom_group, params.slice(:mapping_key, :deleted_at, :integration_group))
    else
      create_custom_field(params.merge(position: find_max_position(params[:section]) + 1))
    end
  end

  def migrate_simple_phone_data_to_international_phone_format(custom_field)
    params = custom_field.attributes.symbolize_keys.slice(:section, :position, :name,
      :help_text, :required, :required_existing, :collect_from, :locks, :custom_section_id)
    params[:name] = "#{params[:name]}#"
    params[:field_type] = CustomField.field_types[:phone]

    ncustom_field = create_custom_field_if_not_exists(params, [], true)

    @company.users.try(:find_each) do |user|
      begin
        phone_number = CustomField.parse_phone_string_to_hash(custom_field.custom_field_values.find_by(user_id: user.id).try(:value_text))
        if phone_number.present?
          CustomFieldValue.set_custom_field_value(user, ncustom_field.name, phone_number[:phone], 'Phone', false)
          CustomFieldValue.set_custom_field_value(user, ncustom_field.name, phone_number[:area_code], 'Area Code', false)
          CustomFieldValue.set_custom_field_value(user, ncustom_field.name, phone_number[:country_alpha3], 'Country', false)
        end
      rescue Exception => e
      end
    end

    @company.update_column(:phone_format, 'International Phone Number')
    ncustom_field.update_column(:name, custom_field.name)
    custom_field.field_histories.update(custom_field_id: ncustom_field.id)
    custom_field.profile_template_custom_field_connections.with_deleted.update_all(custom_field_id: ncustom_field.id)
    custom_field.reload.destroy!
  end

  def migrate_international_phone_data_to_simple_phone_format(custom_field)
    params = custom_field.attributes.symbolize_keys.slice(:section, :position, :name,
      :help_text, :required, :required_existing, :collect_from, :locks, :custom_section_id, :custom_table_id)
    return if params[:custom_table_id].present?
    params[:name] = "#{params[:name]}#"
    params[:field_type] = CustomField.field_types[:simple_phone]

    ncustom_field = create_custom_field_if_not_exists(params, [], true)

    @company.users.try(:find_each) do |user|
      begin
        phone_number = user.get_custom_field_value_text(custom_field.name)
        CustomFieldValue.set_custom_field_value(user, ncustom_field.name, phone_number) if phone_number.present?
      rescue Exception => e
      end
    end

    @company.update_column(:phone_format, 'Standard Phone Number')
    ncustom_field.update_column(:name, custom_field.name)
    custom_field.field_histories.update(custom_field_id: ncustom_field.id)
    custom_field.profile_template_custom_field_connections.with_deleted.update_all(custom_field_id: ncustom_field.id)
    custom_field.reload.destroy!
  end

  def migrate_custom_field_data_to_another_custom_field(name, options = [])
    custom_field = @company.custom_fields.where('name ILIKE ?', name).first
    return unless custom_field.present?

    params = custom_field.attributes.symbolize_keys.slice(:section, :position, :name,
      :help_text, :required, :required_existing, :collect_from, :locks,
      :field_type, :custom_section_id)
    params[:name] = "#{params[:name]}#"
    params[:field_type] = CustomField.field_types[:mcq] if options.present?

    ncustom_field = create_custom_field_if_not_exists(params, options)

    @company.users.try(:find_each) do |user|
      begin
        value = user.get_custom_field_value_text(custom_field.name)
        CustomFieldValue.set_custom_field_value(user, ncustom_field.name, value) if value.present?  
      rescue Exception => e
      end
    end

    ncustom_field.update_column(:name, custom_field.name)
    custom_field.field_histories.update(custom_field_id: ncustom_field.id)
    custom_field.profile_template_custom_field_connections.with_deleted.update_all(custom_field_id: ncustom_field.id)
    custom_field.reload.destroy!
  end
end
