class CustomEmailAlertsCollection < BaseCollection
  private

  def relation
    @relation ||= CustomEmailAlert.all
  end

  def ensure_filters
    company_filter
    timeoff_filter
    location_filter
    team_filter
    employee_type_filter
    sorting_filter
    name_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end
  def timeoff_filter
    filter { |relation| relation.where(alert_type: [4, 5, 7]) } unless params[:enabled_time_off]
  end

  def location_filter
    if params[:location_id] && params[:location_id][0] != nil
      loc_filter = params[:location_id].map(&:to_s)
    end
    filter { |relation| relation.where("ARRAY[?]::varchar[] && applied_to_locations", loc_filter) } if loc_filter
  end

  def team_filter
    if params[:team_id] && params[:team_id][0] != nil
      team_filter = params[:team_id].map(&:to_s)
    end
    filter { |relation| relation.where("ARRAY[?]::varchar[] && applied_to_teams", team_filter) } if team_filter
  end

  def employee_type_filter
    if params[:employment_status_id] &&  params[:employment_status_id][0] != nil && params[:employment_status_id].length > 0
      status_filter = params[:employment_status_id].map(&:to_s)
    end
    filter { |relation| relation.where("ARRAY[?]::varchar[] && applied_to_statuses", status_filter) } if status_filter
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'
      if params[:order_column] == 'title'
        filter { |relation| relation.reorder("title #{order_in}") }
      end
    end
  end

  def name_filter
    data = params[:term] || params["search"]["value"] if params[:term].present? || params["search"] && params["search"]["value"]
    filter do |relation|
      pattern = "%#{data.to_s.downcase}%"
      relation.where("lower(TRIM(title)) LIKE :pattern", pattern: pattern)
    end if data
  end
end
