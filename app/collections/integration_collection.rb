class IntegrationsCollection < BaseCollection
  private

  def relation
    @relation ||= Integration.all
  end

  def ensure_filters
    company_filter
    api_name_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def api_name_filter
    filter { |relation| relation.where(api_name: params[:api_name]) } if params[:api_name]
  end
end
