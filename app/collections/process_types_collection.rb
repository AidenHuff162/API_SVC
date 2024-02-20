class ProcessTypesCollection < BaseCollection
  private

  def relation
    @relation ||= ProcessType.all
  end

  def ensure_filters
    company_filter
    group_type_filter
    onboarding_plan_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]).order(id: :asc) } if params[:company_id]
  end

  def group_type_filter
    filter { |relation| relation.where(process_group_type: params[:process_group_type]) }if params[:process_group_type]
  end

  def onboarding_plan_filter
    filter {|relation| relation.where("LOWER(name) IN (?)", ['onboarding', 'offboarding']) } if params[:onboarding_plan]
  end
end
