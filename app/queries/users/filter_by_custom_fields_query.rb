module Users
  class FilterByCustomFieldsQuery
    def filter_by_custom_fields(**kwargs)
      params = kwargs[:params]
      @users = kwargs[:filtered_users]
      custom_fields = filter_custom_fields_based_on_param_keys(params, kwargs[:custom_fields])
      return @users unless custom_fields

      filter_by_option_fields(params, custom_fields) if (custom_fields.pluck(:field_type) & %w[mcq employment_status]).any?
      filter_by_other_fields(params, custom_fields)
      @users
    end

    private

    def filter_by_option_fields(params, custom_fields)
      @users = @users.includes(custom_field_values: [custom_field_option: :custom_field])
      u_ids = []
      custom_fields.where(field_type: %w[mcq employment_status]).each do |custom_field|
        key = custom_field.employment_status? ? 'employment_status' : custom_field.api_field_id.downcase
        next unless params[key]

        u_ids << @users.where(custom_field_options: { custom_field_id: custom_field.id, option: params[key] }).ids
      end
      @users = @users.where(id: u_ids.flatten.uniq)
    end

    def filter_by_other_fields(params, custom_fields)
      custom_fields = custom_fields.where.not(field_type: %w[mcq employment_status])
      return if custom_fields.length.zero?

      user_ids = iterate_and_filter_users(params, custom_fields)

      @users = @users.where(id: user_ids)
    end

    def iterate_and_filter_users(params, custom_fields)
      filtered_user_ids = []
      @users.each do |user|
        flag = true
        custom_fields.try(:each) do |custom_field|
          args = { user: user, custom_field: custom_field, params: params }
          if custom_field.is_type_plain_text? || %w[multi_select coworker].include?(custom_field.field_type)
            flag = compare_simple_values?(args)
          elsif custom_field.is_type_subfield?
            flag = compare_sub_custom_fields_values?(args)
          end
          break unless flag
        end
        filtered_user_ids << user.id if flag
      end
      filtered_user_ids
    end

    def compare_simple_values?(**kwargs)
      custom_field = kwargs[:custom_field]
      return false if (cfv = kwargs[:user]&.get_custom_field_value_text(custom_field.name)).blank? ||
                      (params_value = kwargs[:params][custom_field.api_field_id.downcase]).blank?

      params_value = JSON.parse(params_value) if custom_field.field_type == 'multi_select'
      (params_value == cfv)
    end

    def compare_sub_custom_fields_values?(**kwargs)
      custom_field = kwargs[:custom_field]
      return false if (cfv = kwargs[:user]&.get_custom_field_value_text(custom_field.name, true)).blank? ||
                      (params_value = kwargs[:params][custom_field.api_field_id.downcase]).blank?

      (cfv.deep_stringify_keys! == JSON.parse(params_value).to_h)
    end

    def filter_custom_fields_based_on_param_keys(params, custom_fields)
      field_ids = params.keys
      field_ids << custom_fields.find_by(field_type: 13)&.api_field_id&.downcase if params['employment_status']
      custom_fields.where('lower(api_field_id) IN (?)', field_ids)
    end

  end
end
