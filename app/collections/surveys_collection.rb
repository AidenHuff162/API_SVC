class SurveysCollection < BaseCollection
  private

  def relation
    @relation ||= Survey.includes(:survey_questions).all.order(:name)
  end

  def ensure_filters
    company_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id])} if params[:company_id]
  end

end
