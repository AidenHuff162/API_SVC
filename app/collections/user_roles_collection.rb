class UserRolesCollection < BaseCollection
  private

  def relation
    @relation ||= UserRole.all
  end

  def ensure_filters
    company_filter
    exclude_permission_level_ids_filter
    only_admin_filter
    name_filter
    section_filter
    location_filter
    team_filter
    employee_type_filter
    profile_page_filter
    ghost_filter
  end

  def ghost_filter
    filter do |relation|
      relation.where.not(name: 'Ghost Admin')
    end if params[:action] == 'simple_index'
  end

  def company_filter
    filter do |relation|
      relation.where(company_id: params[:company_id])
    end if params[:company_id]
  end

  def exclude_permission_level_ids_filter
    filter do |relation|
      relation.where.not(id: params[:permission_level_ids])
    end if params[:permission_level_ids]
  end

  def name_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      name_query = 'concat_ws(\' \', lower(user_roles.name)) LIKE ?'
      relation.where("#{name_query}", pattern)
    end if params[:term]
  end

  def only_admin_filter
    filter do |relation|
      relation.where(role_type: UserRole.role_types[:admin])
    end if params[:term]
  end

  def section_filter
    filter do |relation|
      relation.where("permissions -> 'employee_record_visibility' ->> ? ILIKE '%view%' AND role_type != '0' " , params[:section])
    end if params[:section]
  end

  def location_filter
    filter do |relation|
      relation.where("array_length(location_permission_level, 1) IS NULL OR 'all' = ANY(location_permission_level) OR ? = ANY(location_permission_level)", params[:user_location_id].to_s)
    end if params[:user_location_id]
  end

  def team_filter
    filter do |relation|
      relation.where("array_length(team_permission_level, 1) IS NULL OR 'all' = ANY(team_permission_level) OR ? = ANY(team_permission_level)", params[:user_team_id].to_s)
    end if params[:user_team_id]
  end

  def employee_type_filter
    filter do |relation|
      relation.where("array_length(status_permission_level, 1) IS NULL OR 'all' = ANY(status_permission_level) OR ? = ANY(status_permission_level)", params[:user_employee_type].to_s)
    end if params[:user_employee_type]
  end

  def profile_page_filter
    filter do |relation|
      relation.order('id DESC').pluck(:name).join(", ")
    end if params[:profile_page]
  end
end
