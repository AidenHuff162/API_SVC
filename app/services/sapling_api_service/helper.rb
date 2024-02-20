module SaplingApiService
  class Helper
    def prepare_custom_field_hash_data(user, options)
      user_data_hash = options[:user_data_hash]
      custom_field = options[:custom_field]
      field_name = custom_field.name.parameterize.underscore
      if custom_field.custom_table_id.present?
        field_value = user.get_custom_field_value_text(custom_field.name, true, nil, custom_field, false, nil, true)
        custom_table_name = custom_field.custom_table.name.parameterize.underscore
        user_data_hash[custom_table_name].merge!("#{field_name}": field_value)
      else
        user_data_hash[field_name] = user.get_custom_field_value_text(custom_field.name, true, nil, nil, false, nil, true)
      end
    end
  end
end
