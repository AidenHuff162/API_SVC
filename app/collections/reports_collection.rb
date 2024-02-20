class ReportsCollection < BaseCollection
  private

  def relation
    @relation ||= Report.all
  end

  def ensure_filters
    company_filter
    can_user_access_report_filter
    search_reports_filter
    report_type_filter
    sorting_filter
  end

  def company_filter
    filter do |relation|
      relation.where(company_id: params[:company_id])
    end if params[:company_id]
  end

  def can_user_access_report_filter
    if params[:user_id]
      user = User.find_by_id(params[:user_id])
      filter do |relation|
        relation.where("'?' = ANY (user_role_ids)", user.user_role_id)
      end
    end
  end

  def search_reports_filter
    if params[:term]
      pattern = "%#{params[:term].to_s.downcase}%"
      query = 'lower(TRIM(name)) LIKE ?'
      
      filter do |relation|
        relation.where("#{query}", pattern)
      end
    end
  end

  def report_type_filter
    filter do |relation|
      relation.where(report_type: params[:report_type])
    end if params[:report_type]
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:order_column] == 'name'
        filter { |relation| relation.reorder("name #{order_in}") }
      elsif params[:order_column] == 'created_by'
        filter { |relation| relation.joins(:users).reorder("users.preferred_full_name #{order_in}") }
      elsif params[:order_column] == 'created_on'
        filter { |relation| relation.reorder("created_at #{order_in}") }
      end
    end
  end
end
