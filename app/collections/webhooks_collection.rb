class WebhooksCollection < BaseCollection
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    @results ||= begin
      relation
    end
  end

  def count
    records_count
  end

  private

  def records_count
    ActiveRecord::Base.connection.exec_query("
      SELECT webhooks.*,
      (SELECT webhook_events.triggered_at from webhook_events WHERE webhook_events.webhook_id = webhooks.id ORDER BY webhook_events.triggered_at desc limit(1)) AS triggered_at
      from webhooks
      WHERE #{where_clause}
      #{term_filter}
    ").count.to_i
  end

  def relation
    @relation ||= ActiveRecord::Base.connection.exec_query("
      SELECT webhooks.*,
      (SELECT webhook_events.triggered_at from webhook_events WHERE webhook_events.webhook_id = webhooks.id AND webhook_events.triggered_at IS NOT NULL ORDER BY webhook_events.triggered_at desc limit(1)) AS triggered_at
      from webhooks
      WHERE #{where_clause}
      #{term_filter}
      ORDER BY #{sorting_filter}
      OFFSET #{(params[:page] - 1) * params[:per_page].to_i}
      LIMIT #{params[:per_page]}
    ")
  end

  def where_clause
    "webhooks.company_id = #{params[:company_id]}"
  end

  def sorting_filter
    sorting = ""
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'
      if params[:order_column] == 'triggered_at'
        sorting = "triggered_at #{order_in}"
      elsif params[:order_column] == 'event'
        sorting = "(case event
          when 0 then '#{Webhook.events.key(0)}'
          when 1 then '#{Webhook.events.key(1)}'
          when 2 then '#{Webhook.events.key(2)}'
          when 3 then '#{Webhook.events.key(3)}'
          when 4 then '#{Webhook.events.key(4)}'
          when 5 then '#{Webhook.events.key(5)}'
          end) #{order_in}"
      end
    end
    sorting
  end

  def term_filter
    data = params[:term] if params[:term].present?
    " AND (case event
      when 0 then '#{Webhook.events.key(0)}'
      when 1 then '#{Webhook.events.key(1)}'
      when 2 then '#{Webhook.events.key(2)}'
      when 3 then '#{Webhook.events.key(3)}'
      when 4 then '#{Webhook.events.key(4)}'
      when 5 then '#{Webhook.events.key(5)}'
      end) ILIKE '%#{data}%' " if data
  end
end
