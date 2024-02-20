class IntegrationCustomMappingHelper
  
  def get_user_field_values(user, meta, field_name)
    if meta[:is_custom].blank?  
      case field_name
      when 'location'
        user.get_location_name
      when 'department'
        user.get_team_name
      else
        user.attributes[field_name.tr(' ', '_')]
      end
    else
      user.get_custom_field_value_text(field_name)
    end
  end

  def add_custom_sync_field_data(data, key, integration_instance, user, company)
    int_field_mapper = IntegrationFieldMapping.fetch_mapping_against_key(key, integration_instance.id)
    return nil unless int_field_mapper.present?
    custom_sync_field_name = int_field_mapper.get_field_name(company)
    get_user_field_values(user, {is_custom: int_field_mapper.is_custom}, custom_sync_field_name) if custom_sync_field_name
  end

  def change_params_mapper_for_custom_field_mapping(params_mapper, integration_instance, company, mode = 'push')
    return unless integration_instance.integration_field_mappings.present?
    integration_instance.integration_field_mappings.find_each do |mapper|
      update_key = 'update_' + mapper.integration_field_key

      if mapper.preference_field_id == 'null' && mapper.custom_field_id == nil
        params_mapper.delete(mapper.integration_field_key.to_sym)
        params_mapper.delete(update_key.to_sym)
      end

      if params_mapper.key?(mapper.integration_field_key.to_sym)
        sapling_field_name = mapper.is_custom ? integration_instance.custom_field_name(mapper.custom_field_id, company) : integration_instance.get_preference_field_name(mapper.preference_field_id, company)
        if sapling_field_name.present?
          if mode == 'push'
            change_mapper_attributes(params_mapper, mapper.integration_field_key.to_sym, {name: sapling_field_name, is_custom: mapper.is_custom})
            if params_mapper.key?(update_key.to_sym)
              change_mapper_attributes(params_mapper, update_key.to_sym, {name: sapling_field_name, is_custom: mapper.is_custom})
            end
          elsif mode == 'pull'
            params_mapper[mapper.integration_field_key.to_sym][:is_custom] = mapper.is_custom
            params_mapper[sapling_field_name.tr(" ", "_").to_sym] = params_mapper.delete(mapper.integration_field_key.to_sym)
          end
        else
          params_mapper.delete(mapper.integration_field_key.to_sym)
          params_mapper.delete(update_key.to_sym) if params_mapper.key?(update_key.to_sym)
        end
      end
    end

    params_mapper
  end

  def change_mapper_attributes(params_mapper, key, hash_value)
    params_mapper[key].merge!(hash_value)
  end

  def get_numeric_salary(user)
    annual_salary_field = user.company.custom_fields.find_by(name: 'Annual Salary')
    annual_salary = 
      if annual_salary_field && annual_salary_field.currency?
        user.get_custom_field_value_text('Annual Salary', false, 'Currency Value')
      else
        user.get_custom_field_value_text('Annual Salary')
      end
    
    
    annual_salary&.gsub!(/[^0-9]/, '')
    
    return annual_salary
  end
end
