class PtoPoliciesCollection < BaseCollection
  private

  def relation
    @relation ||= PtoPolicy.all
  end

  def ensure_filters
    company_filter
    name_filter
    policy_type_filter
    location_filter
    team_filter
    employee_type_filter
    sorting_filter
    enable_filter
    unassigned_to_current_user_filter
    limited_filter
    unlimited_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def enable_filter
    filter { |relation| relation.where(is_enabled: true) } if params[:enabled]
  end

  def limited_filter
    filter { |relation| relation.where(unlimited_policy: false) } if params[:limited_policies] && params[:unlimited_policies].blank?
  end

  def name_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      name_query = 'concat_ws(\' \', lower(name)) LIKE ?'

      relation.where("#{name_query}", pattern)
    end if params[:term]
  end

  def sorting_filter
    if params[:sort_column] && params[:sort_order]
      order_in = params[:sort_order].downcase == 'asc' ? 'asc' : 'desc'

      if params[:sort_column] == 'policy_type'
        filter { |relation| relation.reorder("case policy_type
          when 0 then 'other'
          when 1 then 'vacation'
          when 2 then 'sick'
          when 3 then 'parental_leave'
          when 4 then 'jury_duty'
          when 5 then 'training'
          when 6 then 'study'
          when 7 then 'work_from_home'
          when 8 then 'out_of_office'
          when 9 then 'vaccination'
        end #{order_in}") }
      elsif params[:sort_column] == 'name'
        filter { |relation| relation.reorder("lower(name) #{order_in}") }
      elsif params[:sort_column] == 'position'
        filter { |relation| relation.reorder("position #{order_in}") }       
      end
    end
  end

  def unassigned_to_current_user_filter
    if params[:current_user_id]
      assigned_policy_ids = User.find(params[:current_user_id]).pto_policies.pluck(:id)
      filter { |relation| relation.where.not(id: assigned_policy_ids) }
    end
  end

  def policy_type_filter
    filter { |relation| relation.where(policy_type: params[:policy_type_id]) } if params[:policy_type_id].present?
  end

  def location_filter
    if params[:location_id].present?
      filter { |relation| relation.where("filter_policy_by -> 'location' @> ? OR filter_policy_by -> 'location' @> ? ", ['all'].to_s, params[:location_id].to_s) }
    end
  end
  def team_filter
    if params[:team_id].present?
      filter { |relation| relation.where("filter_policy_by -> 'teams' @> ? OR filter_policy_by -> 'teams' @> ?", ['all'].to_s, params[:team_id].to_s) }
    end
  end

  def employee_type_filter
    if params[:employment_status].present?
      filter { |relation| relation.where("filter_policy_by -> 'employee_status' @> ? OR filter_policy_by -> 'employee_status' @> ?", ['all'].to_s, params[:employment_status].to_s) }
    end
  end

  def unlimited_filter
    filter { |relation| relation.where(unlimited_policy: true) } if params[:unlimited_policies] && params[:limited_policies].blank?
  end
end
