class HistoriesCollection < BaseCollection
  private

  def relation
    @relation ||= History.all
  end

  def ensure_filters
    company_filter
    event_term_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def event_term_filter
    filter do |relation|
      pattern = params[:term].to_s.downcase
      relation.where(id: relation.select { |history| history.description.present? and history.description.gsub(/<\/?[^>]+>/, '').downcase.include? pattern }.map(&:id))
    end if params[:term]
  end
end
