class CompanyLinksCollection < BaseCollection
  private

  def relation
    @relation ||= CompanyLink.all
  end

  def ensure_filters
    company_filter
    employee_filter if params[:employee_id] && params[:company]
  end

  def employee_filter
    employee = params[:company].users.where(id: params[:employee_id]).first
    dept_filter = build_array employee&.team_id
    loc_filter = build_array employee&.location_id
    stat_filter = build_array employee&.get_employment_status_option
    filter { |relation| relation.where("(ARRAY[?]::varchar[] && location_filters) AND (ARRAY[?]::varchar[] && team_filters) AND (ARRAY[?]::varchar[] && status_filters)", loc_filter, dept_filter, stat_filter)} 
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company].id)} if params[:company]
  end

  def build_array id
    array = id.present? ? [id].map(&:to_s).push('all') : ['all']
  end
end