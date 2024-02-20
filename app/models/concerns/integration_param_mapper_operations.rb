module IntegrationParamMapperOperations
  extend ActiveSupport::Concern
  
  def fetch_integration_params_mapper
    params_mapper_hash = {}
    company = self.company
    mappings = self.integration_field_mappings.order(field_position: :ASC)
    mappings.each do |entry|
      field_name = entry.preference_field_id == 'ui' ? 'id' : get_name(entry, company)
      params_mapper_hash[entry.integration_field_key.to_sym] = {name: field_name,
      is_custom: entry.is_custom, exclude_in_create: entry.exclude_in_create,
      exclude_in_update: entry.exclude_in_update, parent_hash_path: entry.parent_hash_path, 
      parent_hash: entry.parent_hash}
    end
    params_mapper_hash
  end

  def get_name entry, company
    entry.custom_field_id.present? ? custom_field_name(entry.custom_field_id, company) : get_preference_field_name(entry.preference_field_id, company) 
  end

  def custom_field_name custom_field_id, company
    company.custom_fields.find_by(id: custom_field_id)&.name&.downcase
  end

  def get_preference_field_name preference_field_id, company
    case preference_field_id
    when 'email'
      return preference_field_id
    else
      company.prefrences['default_fields'].map {|field| field['name'].downcase if preference_field_id == field['id'] }.compact.first
    end
  end

  def get_field_name(company)
    if self.is_custom
      custom_field_name(self.custom_field_id, company)
    else
      get_preference_field_name(self.preference_field_id, company)
    end
  end

  def mapper_hash
    {
      firstName: { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      importKey: { name: 'user id', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      lastName: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      userName: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      emailAddress: { name: 'company email', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      startDate: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      isEnabled: { name: 'status', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      leaveDate: { name: 'last day worked', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      jobTitle: { name: 'job title', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      managerImportKey: { name: 'manager', is_custom: false, exclude_in_create: false, exclude_in_update: false }
    }
  end

  def create_integration_field_mappings params_mapper = nil
    params_mapper_hash = params_mapper.present? ? params_mapper : mapper_hash
    company = self.company
    count = 1
    params_mapper_hash.each do |key, value|
      custom_field_id, preference_field_id = get_field_id(value, company)
      self.integration_field_mappings.find_or_create_by!(integration_field_key: key,
      custom_field_id: custom_field_id,
      preference_field_id: preference_field_id,
      is_custom: value[:is_custom],
      exclude_in_update: value[:exclude_in_update],
      exclude_in_create: value[:exclude_in_create],
      parent_hash: value[:parent_hash],
      parent_hash_path: value[:parent_hash_path],
      field_position: count,
      company_id: company.id) rescue nil
      count += 1
    end
  end

  def get_field_id value, company
    if value[:is_custom].present?
      return get_custom_field_id(value[:name], company), nil
    else
      return nil, get_prefrence_field_id(value[:name], company)
    end
  end

  def get_custom_field_id field_name, company
    company.custom_fields.where('name ILIKE ?', field_name).take&.id
  end

  def get_prefrence_field_id field_name, company
    case field_name
    when 'email'
      return field_name
    else
      company.prefrences['default_fields'].map {|field| field['id'] if field_name == field['name'].downcase }.compact.first
    end
  end
end
  