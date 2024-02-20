module UserSerializer
  class EmployeeRecordCsv < Base
    attributes :id, :title, :role, :email, :start_date,
               :team, :location, :manager, :buddy, :job_tier,
               :personal_email, :manager_id

    def attributes(*attrs)
      data = super
      role = current_user.user_role.role_type
      if role
        if role == 'super_admin'

          object.company.prefrences["default_fields"].each do |field|
            if field["section"] == "profile"
              field_name = field["name"].try(:downcase).to_s
              unless field_name == "about"
                data[:"custom_#{field_name.parameterize.underscore}"] = object.profile[field_name]
              else
                data[:"custom_about"] = object.profile["about_you"]
              end
            end
          end

          profile_info_cf = object.company.custom_fields.where('custom_fields.section = ?', 1)
          profile_info_cf.each do |profile_cf|            
            data[:"custom_#{profile_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, profile_cf, false, nil, false, false, false, false, nil, false, true)
          end

          personal_info_cf = object.company.custom_fields.where('custom_fields.section = ?', 0)
          personal_info_cf.each do |personal_cf|
            data[:"custom_#{personal_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, personal_cf, false, nil, false, false, false, false, nil, false, true)
          end

          additional_access_cf = object.company.custom_fields.where('custom_fields.section = ?', 2)
          additional_access_cf.each do |additional_cf|
            data[:"custom_#{additional_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, additional_cf, false, nil, false, false, false, false, nil, false, true)
          end

          private_access_cf = object.company.custom_fields.where('custom_fields.section = ?', 4)
          private_access_cf.each do |private_cf|
            data[:"custom_#{private_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, private_cf, false, nil, false, false, false, false, nil, false, true)
          end
        else
          if role == 'admin' || role == 'manager'
            visibility_check = "own_info_visibility"
          elsif (role == 'employee')
            visibility_check = "employee_record_visibility"
          end

          if current_user.user_role.permissions[visibility_check]["profile_info"] != "no_access"
            object.company.prefrences["default_fields"].each do |field|
              if field["section"] == "profile"
                field_name = field["name"].try(:downcase).to_s
                unless field_name == "about"
                  data[:"custom_#{field_name.parameterize.underscore}"] = object.profile[field_name]
                else
                  data[:"custom_about"] = object.profile["about_you"]
                end
              end
            end

            profile_info_cf = object.company.custom_fields.where('custom_fields.section = ?', 1)
            profile_info_cf.each do |profile_cf|
              data[:"custom_#{profile_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, profile_cf, false, nil, false, false, false, false, nil, false, true)
            end
          end

          if current_user.user_role.permissions[visibility_check]["personal_info"] != "no_access"
            personal_info_cf = object.company.custom_fields.where('custom_fields.section = ?', 0)
            personal_info_cf.each do |personal_cf|
              data[:"custom_#{personal_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, personal_cf, false, nil, false, false, false, false, nil, false, true)
            end
          end

          if current_user.user_role.permissions[visibility_check]["additional_info"] != "no_access"
            additional_access_cf = object.company.custom_fields.where('custom_fields.section = ?', 2)

            additional_access_cf.each do |additional_cf|
              data[:"custom_#{additional_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, additional_cf, false, nil, false, false, false, false, nil, false, true)
            end
           end

          if current_user.user_role.permissions[visibility_check]["private_info"] != "no_access"
            private_access_cf = object.company.custom_fields.where('custom_fields.section = ?', 4)

            private_access_cf.each do |private_cf|
              data[:"custom_#{private_cf.name.parameterize.underscore}"] = object.get_custom_field_value_text(nil, false, nil, private_cf, false, nil, false, false, false, false, nil, false, true)
            end
          end
        end
      end
      data
    end

    def team
     object.team.name if object.team
    end

    def location
      object.location.name if object.location
    end

    def manager
      object.manager.full_name if object.manager
    end

    def buddy
      object.buddy.full_name if object.buddy
    end

    def employee_type
      object.employee_type
    end
  end
end
