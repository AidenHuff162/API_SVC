class PtoRequestsCollection < BaseCollection
  private

  def relation
    @relation ||= PtoRequest.all
  end

  def ensure_filters
    user_company_filter
    status_filter
    out_of_office_filter
    inactive_employees_filter
  end

  def user_company_filter
    filter do |relation|
      relation.joins(:user).where(users: {company_id: params[:company_id]})
    end if params[:company_id]
  end

  def status_filter
    filter { |relation| relation.where(status: params[:status]) } if params[:status]
  end

  def out_of_office_filter
    date = Company.find_by(id: params[:company_id]).time.to_date
    filter { |relation| relation.where("pto_requests.status = 1 AND pto_requests.begin_date <= :date AND pto_requests.end_date <= :date_limit AND pto_requests.end_date >= :date", date: date, date_limit: date + 14.days).order(:end_date) } if params[:out_of_office]
  end

  def inactive_employees_filter
    filter do |relation|
      relation.joins(:user).where.not(users: {current_stage: [User.current_stages[:incomplete], User.current_stages[:departed], User.current_stages[:offboarding], User.current_stages[:last_month], User.current_stages[:last_week]]}).where(users: {state: 'active'})
    end if params[:active_employees]
  end

end
