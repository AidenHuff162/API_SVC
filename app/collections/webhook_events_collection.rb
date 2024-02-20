class WebhookEventsCollection < BaseCollection
  private

  def relation
    @relation ||= WebhookEvent.all
  end

  def ensure_filters
    company_filter
    webhook_filter
    sorting_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def webhook_filter
    filter { |relation| relation.where(webhook_id: params[:webhook_id]) } if params[:webhook_id]
  end

  def sorting_filter
    filter { |relation| relation.reorder("triggered_at DESC") }
  end

end
