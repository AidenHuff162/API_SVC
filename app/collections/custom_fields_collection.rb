class CustomFieldsCollection < BaseCollection
  private

  def relation
    @relation ||= CustomField.all
  end

  def ensure_filters
    deleted_at_filter
    company_filter
    profile_fields_filter
    onboarding_page_filter
    employment_status_filter
    create_profile_filter
    offboarding_page_filter
    preboarding_page_filter
    reporting_page_filter
    home_info_fields_filter
    coworker_fields_filter
    section_filter
    group_filter
    name_filter
    id_filter
    collect_from_filter
    bulk_onboarding_filter
    access_fields_filter
    type_filter
    skip_employment_status
    paginate_groups
    term_filter
    group_sa_configuration_filter
    sa_configuration_onboarding_filter
    national_id_field_filter
  end

  def create_profile_filter
    if params[:is_create_profile]
      if params[:is_using_custom_table].present?
        filter { |relation| relation.joins("LEFT JOIN custom_tables ON custom_tables.id = custom_fields.custom_table_id")
          .where("custom_fields.name LIKE 'Employment Status' OR custom_fields.name LIKE 'Job Tier' OR custom_fields.name LIKE 'ADP Company Code' OR custom_fields.name LIKE 'Google Groups' OR custom_fields.name LIKE 'Google Organization Unit'")
        }
      else
        filter { |relation| relation.where("custom_fields.name LIKE 'Employment Status' OR custom_fields.name LIKE 'Job Tier' OR custom_fields.name LIKE 'ADP Company Code' OR custom_fields.name LIKE 'Google Groups' OR custom_fields.name LIKE 'Google Organization Unit'")
        }
      end
    end
  end

  def onboarding_page_filter
    if params[:is_onboarding_page]
      filter { |relation| relation.joins("LEFT JOIN custom_tables ON custom_tables.id = custom_fields.custom_table_id")
        .where("((custom_fields.custom_table_id IS NOT NULL AND custom_fields.name NOT LIKE 'Effective Date') OR (custom_fields.custom_table_id IS NULL AND custom_fields.section IS NOT NULL)) AND custom_fields.name NOT LIKE 'Employment Status' AND custom_fields.name NOT LIKE 'Job Tier' AND custom_fields.name NOT LIKE 'ADP Company Code' AND custom_fields.name NOT LIKE 'Google Groups' AND custom_fields.name NOT LIKE 'Google Organization Unit'")
      }
    end
  end

  def employment_status_filter
    if params[:employment_status]
      filter { |relation| relation.where("custom_fields.field_type = ?", CustomField.field_types[:employment_status]) }
    end
  end

  def offboarding_page_filter
    if params[:is_offboarding_page]
      filter { |relation| relation.joins("LEFT JOIN custom_tables ON custom_tables.id = custom_fields.custom_table_id") }
    end
  end

  def preboarding_page_filter
    filter { |relation| relation.where('custom_table_id IS NULL AND collect_from = ?', CustomField.collect_froms[:new_hire])
      .where.not(id: params[:invisible_field_ids]) } if params[:is_preboarding_page]
  end

  def reporting_page_filter
    if params[:is_reporting_page]
      filter { |relation| relation.joins("LEFT JOIN custom_tables ON custom_tables.id = custom_fields.custom_table_id")
        .where("custom_fields.custom_table_id IS NULL OR (custom_fields.custom_table_id = custom_tables.id AND
          custom_tables.custom_table_property = ? AND custom_fields.field_type = ?)",
          CustomTable.custom_table_properties[:employment_status], CustomField.field_types[:employment_status])
        }
    end
  end

  def home_info_fields_filter
    filter { |relation| relation.where(custom_table_id: nil, section: params[:sections]) } if params[:is_info_page].present?
  end

  def coworker_fields_filter  
    filter { |relation| relation.where(field_type: 'coworker') } if params[:coworker].present?
  end

  def profile_fields_filter
    filter { |relation| relation.where(custom_table_id: nil) } if params[:is_profile_fields]
  end

  def deleted_at_filter
    filter { |relation| relation.where(deleted_at: nil) }
  end

  def id_filter
    filter { |relation| relation.where(id: params[:id]) } if params[:id]
  end

  def company_filter
    filter do |relation|
      relation.where(company_id: params[:company_id])
    end if params[:company_id]
  end

  def section_filter
    filter do |relation|
      if params[:section].is_a? Numeric
        relation.where(section: params[:section])
      else
        relation.where(section: CustomField.sections[params[:section]])
      end
    end if params[:section]
  end

  def group_filter
    filter do |relation|
      relation.where.not(integration_group: CustomField.integration_groups[:no_integration])
    end if params[:integration_group] && params[:company_id]
  end

  def group_sa_configuration_filter
    return unless params[:sa_configuration_filters]
    sa_custom_group_ids = []
    sa_config = SmartAssignmentConfiguration.find_by_company_id(params[:company_id])
    return if sa_config.nil?
    sa_custom_group_ids = sa_config.meta["activity_filters"] if sa_config.meta["activity_filters"] 
    filter do |relation|
      relation.where(id: sa_custom_group_ids)
    end
  end

  def sa_configuration_onboarding_filter
    return unless params[:sa_configuration_onboarding_filters]
    sa_custom_group_ids = []
    sa_config = SmartAssignmentConfiguration.find_by_company_id(params[:company_id])
    return if sa_config.nil?
    sa_custom_group_ids = sa_config.meta["smart_assignment_filters"] if sa_config.meta["smart_assignment_filters"] 
    filter do |relation|
      relation.where(id: sa_custom_group_ids)
    end
  end

  def skip_employment_status
    filter do |relation|
      relation.where.not(field_type: :employment_status)
    end if params[:skip_employment_status]
  end

  def name_filter
    filter { |relation| relation.where(name: params[:name])} if params[:name]
  end

  def collect_from_filter
    filter { |relation| relation.where(collect_from: CustomField::collect_froms[params[:collect_from]])} if params[:collect_from]
  end

  def bulk_onboarding_filter
    filter { |relation| relation.where("collect_from = ? OR ats_mapping_key IS NOT NULL OR workday_mapping_key IS NOT NULL", CustomField::collect_froms[:admin])} if params[:bulk_onboarding]
  end

  def access_fields_filter
    if params[:check_access].present? && params[:user_id].present?
      user = User.find(params[:user_id])
      permissions = User.find(params[:current_user_id])&.user_role&.permissions['employee_record_visibility'] rescue nil

      if !permissions.present?
        filter { |relation| relation.where.not("section IN (#{CustomField::sections[:additional_fields]}, #{CustomField::sections[:private_info]}, #{CustomField::sections[:personal_info]})") }
      else
        if params[:current_user_id].to_i != params[:user_id].to_i
          if params[:current_user_role].role_type == 'employee'
            filter { |relation| relation.where.not("section IN (#{CustomField::sections[:additional_fields]}, #{CustomField::sections[:private_info]}, #{CustomField::sections[:personal_info]})") }

          elsif params[:current_user_role].role_type == 'manager'
            if params[:current_user_role].reporting_level == 'direct'
              if params[:current_user_id].to_i == user.manager_id
                filter { |relation| relation.where.not(section: CustomField::sections[:private_info]) } if permissions['private_info'] == 'no_access'
                filter { |relation| relation.where.not(section: CustomField::sections[:personal_info]) } if permissions['personal_info'] == 'no_access'
                filter { |relation| relation.where.not(section: CustomField::sections[:additional_fields]) } if permissions['additional_info'] == 'no_access'
              else
                filter { |relation| relation.where.not("section IN (#{CustomField::sections[:additional_fields]}, #{CustomField::sections[:private_info]}, #{CustomField::sections[:personal_info]})") }
              end
            else
              managed_user_ids = User.find(params[:current_user_id]).managed_user_ids rescue []
              if params[:current_user_id].to_i == user.manager_id  || managed_user_ids.include?(user.manager_id)
                filter { |relation| relation.where.not(section: CustomField::sections[:private_info]) } if permissions['private_info'] == 'no_access'
                filter { |relation| relation.where.not(section: CustomField::sections[:personal_info]) } if permissions['personal_info'] == 'no_access'
                filter { |relation| relation.where.not(section: CustomField::sections[:additional_fields]) } if permissions['additional_info'] == 'no_access'
              else
                filter { |relation| relation.where.not("section IN (#{CustomField::sections[:additional_fields]}, #{CustomField::sections[:private_info]}, #{CustomField::sections[:personal_info]})") }
              end
            end

          elsif params[:current_user_role].role_type == 'admin'
            location_level = (params[:current_user_role].location_permission_level && (params[:current_user_role].location_permission_level.include?('all') || params[:current_user_role].location_permission_level.include?(user.location_id.try(:to_s))))
            team_level = (params[:current_user_role].team_permission_level && (params[:current_user_role].team_permission_level.include?('all') || params[:current_user_role].team_permission_level.include?(user.team_id.try(:to_s))))
            status_level = (params[:current_user_role].status_permission_level && (params[:current_user_role].status_permission_level.include?('all') || params[:current_user_role].status_permission_level.include?(user.employee_type)))

            if location_level.present? && team_level.present? && status_level.present?
              filter { |relation| relation.where.not(section: CustomField::sections[:private_info]) } if permissions['private_info'] == 'no_access'
              filter { |relation| relation.where.not(section: CustomField::sections[:personal_info]) } if permissions['personal_info'] == 'no_access'
              filter { |relation| relation.where.not(section: CustomField::sections[:additional_fields]) } if permissions['additional_info'] == 'no_access'
            else
              filter { |relation| relation.where.not("section IN (#{CustomField::sections[:additional_fields]}, #{CustomField::sections[:private_info]}, #{CustomField::sections[:personal_info]})") }
            end
          elsif params[:current_user_role].role_type == 'super_admin'
            filter { |relation| relation.where.not(section: CustomField::sections[:private_info]) } if permissions['private_info'] == 'no_access'
            filter { |relation| relation.where.not(section: CustomField::sections[:personal_info]) } if permissions['personal_info'] == 'no_access'
            filter { |relation| relation.where.not(section: CustomField::sections[:additional_fields]) } if permissions['additional_info'] == 'no_access'
          end
        else
          if params[:current_user_role].role_type == 'employee'
            filter { |relation| relation.where.not(section: CustomField::sections[:private_info]) } if permissions['private_info'] == 'no_access'
            filter { |relation| relation.where.not(section: CustomField::sections[:personal_info]) } if permissions['personal_info'] == 'no_access'
            filter { |relation| relation.where.not(section: CustomField::sections[:additional_fields]) } if permissions['additional_info'] == 'no_access'
          elsif params[:current_user_role].role_type == 'manager' || params[:current_user_role].role_type == 'admin'
            permissions = User.find(params[:current_user_id])&.user_role&.permissions['own_info_visibility'] rescue nil
            filter { |relation| relation.where.not(section: CustomField::sections[:private_info]) } if permissions['private_info'] == 'no_access'
            filter { |relation| relation.where.not(section: CustomField::sections[:personal_info]) } if permissions['personal_info'] == 'no_access'
            filter { |relation| relation.where.not(section: CustomField::sections[:additional_fields]) } if permissions['additional_info'] == 'no_access'
          end
        end
      end
    end
  end

  def type_filter
    filter { |relation| relation.where(field_type: params[:field_type])} if params[:field_type]
  end

  def paginate_groups
    filter { |relation| relation.find_by(id: params[:custom_group_id]).custom_field_options.limit(params[:per_page]).offset((params[:page] - 1) * params[:per_page].to_i).order(order_by) } if params[:custom_group_id]
  end

  def order_by
    order = ""
    order = params[:sort_column]
    order += " " +params[:sort_order]
    order
  end

  def term_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"
      relation.where("option ILIKE ?", pattern)
    end if params[:term]
  end

  def national_id_field_filter
    return if relation.klass != CustomField

    filter do |relation|
      relation.where.not(field_type: CustomField.field_types[:national_identifier])
    end unless Company.find_by_id(params[:company_id])&.national_id_field_feature_flag
  end
end
