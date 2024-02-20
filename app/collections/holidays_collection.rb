class HolidaysCollection < BaseCollection
  private

  def relation
    @relation ||= Holiday.all
  end

  def ensure_filters
    company_filter
    year_filter
    sorting_filter
    user_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def year_filter
    filter { |relation| relation.where("extract(year from begin_date) = ?", params[:current_year]) } if params[:current_year]
  end

  def user_filter
    if params[:user_holidays] && params[:user_id]
      user = User.find_by(id: params[:user_id])
      if user
        filter { |relation| relation.where("('all' = ANY (team_permission_level) OR ?  = ANY (team_permission_level)) AND ('all' = ANY (location_permission_level) OR ?  = ANY (location_permission_level)) AND ('all' = ANY (status_permission_level) OR ?  = ANY (status_permission_level)) AND (begin_date BETWEEN ? AND ?)", user.team_id.to_s, user.location_id.to_s, user.employee_type, Date.today, Date.today + 90.days)}
      end
    end
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:order_column] == 'name'
        filter { |relation| relation.reorder("name #{order_in}") }
      elsif params[:order_column] == 'date_range'
        filter { |relation| relation.reorder("begin_date #{order_in}") }
      end
    end
  end
end
