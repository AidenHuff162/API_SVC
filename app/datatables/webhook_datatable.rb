class WebhookDatatable < ApplicationDatatable
  delegate  to: :@view

  private

  def data
    @loggings = fetch_loggings(my_search(WebhookLogging))
    @loggings.map do |log|
      [].tap do |column|
        column << log.company_name
        column << log.integration
        column << log.action
        column << log.status
        column << (DateTime.strptime(log.timestamp, '%Q').strftime('%d %b %Y  %H:%M:%S') rescue nil)
        column << display_action(log.timestamp)
      end
    end
  end

  def count
    @count ||= WebhookLogging.count
  end

  def my_search loggings
    if params[:company_name].present?
      loggings = loggings.where('company_name': params[:company_name])
    end
    if params[:integration].present?
      loggings = loggings.where('integration': params[:integration])
    end
    if params[:error_message].present?
      loggings = loggings.where('error_message.contains': params[:error_message])
    end
    if params[:data_received].present?
      loggings = loggings.where('data_received.contains': params[:data_received])
    end
    if params[:actions].present?
      loggings = loggings.where('action.contains': params[:actions])
    end
    if params[:status].present?
      loggings = loggings.where(status: params[:status])
    end
    if params[:date_from].present? && params[:date_to].present?
      loggings = loggings.where('timestamp.between':[params[:date_from].to_datetime.beginning_of_day.strftime('%Q'), params[:date_to].to_datetime.end_of_day.strftime('%Q')])
    elsif params[:date_from].present?
      loggings = loggings.where('timestamp.gt': params[:date_from].to_datetime.beginning_of_day.strftime('%Q'))
    elsif params[:date_to].present?
      loggings = loggings.where('timestamp.lt': params[:date_to].to_datetime.end_of_day.strftime('%Q'))
    end
    if params[:company_name].empty? && params[:integration].empty? && params[:status].empty?
      loggings = loggings.where(partition_id: '2')
    end
    loggings
  end

  def display_action id
    action_html = ("<button class='btn btn-default sm btn-font-sm' onClick='show_webhook_logs(#{id})'>
        <i class='fa fa-info-circle'></i>
        </button>").html_safe
    action_html
  end
end
