class CalendarFeedsCollection < BaseCollection
  private

  def relation
    @relation ||= CalendarFeed.all
  end

  def ensure_filters
    company_filter
    user_filter
    feed_type_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def user_filter
    filter { |relation| relation.where(user_id: params[:user_id]) } if params[:user_id]
  end

  def feed_type_filter
    filter { |relation| relation.where(feed_type: CalendarFeed.feed_types[params[:feed_type]]) } if params[:feed_type]
  end
end
