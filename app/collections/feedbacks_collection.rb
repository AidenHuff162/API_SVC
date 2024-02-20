class FeedbacksCollection < BaseCollection
  private

  def relation
    @relation ||= Feedback.all
  end

  def ensure_filters
    company_filter
    user_filter
    module_filter
  end

  def company_filter
    return unless params[:company_id]

    filter { |relation| relation.where(company_id: params[:company_id]) }
  end

  def user_filter
    return unless params[:user_id]

    filter { |relation| relation.where(user_id: params[:user_id]) }
  end

  def module_filter
    return unless params[:module]

    filter { |relation| relation.where(module: params[:module]) }
  end
end
