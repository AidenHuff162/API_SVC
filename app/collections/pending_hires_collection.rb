class PendingHiresCollection < BaseCollection

  def duplication_count_filter
    filter { |relation| relation.where.not(duplication_type: nil).where.not(duplication_type: PendingHire.duplication_types[:rehire]).count }
  end

  private

  def relation
    @relation ||= PendingHire.all
  end

  def ensure_filters
    company_filter
    name_filter
    sorting_filter
    active_filter
    location_filter
    team_filter
    employee_type_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def name_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      name_query = 'concat_ws(\' \', lower(pending_hires.first_name), lower(pending_hires.last_name)) LIKE ?'

      relation.where("#{name_query}", pattern)
    end if params[:term]
  end

  def active_filter
    filter { |relation| relation.where(state: 'active') }
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:order_column] == 'name'
        filter { |relation| relation.reorder("first_name #{order_in}") }

      elsif ['title', 'email', 'current_stage', 'employee_type'].include?(params[:order_column])
        filter { |relation| relation.reorder("#{params[:order_column]} #{order_in}") }

      elsif params[:order_column] == 'start_date'
        filter { |relation| relation.reorder("CAST(start_date AS TIMESTAMP) #{params[:order_in]}") }

      elsif params[:order_column] == 'team_name'
        filter { |relation| relation.joins("LEFT OUTER JOIN teams ON teams.id = pending_hires.team_id").reorder("teams.name #{order_in}") }

      elsif params[:order_column] == 'location_name'
        filter { |relation| relation.joins("LEFT OUTER JOIN locations ON locations.id = pending_hires.location_id").reorder("locations.name #{order_in}") }

      elsif params[:order_column] == 'manager_name'
        filter { |relation| relation.joins("LEFT OUTER JOIN users AS manager ON manager.id = pending_hires.manager_id").reorder("manager.first_name #{order_in}") }
      end
    end
  end

  def location_filter
    if params[:location_id] && params[:location_id][0] != nil
      filter { |relation| relation.where(location_id: params[:location_id]) } if params[:location_id]
    end
  end

  def team_filter
    if params[:team_id] && params[:team_id][0] != nil
      filter { |relation| relation.where(team_id: params[:team_id]) } if params[:team_id]
    end
  end

  def employee_type_filter
    if params[:employment_status_id] &&  params[:employment_status_id][0] != nil && params[:employment_status_id].length > 0
      filter { |relation| relation.where(employee_type: params[:employment_status_id]) } if params[:employment_status_id]
    end
  end
end
