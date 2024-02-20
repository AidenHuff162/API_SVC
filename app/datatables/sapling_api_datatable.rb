class SaplingApiDatatable < ApplicationDatatable
  delegate  to: :@view

  private

  def data
    @loggings = fetch_loggings(my_search(SaplingApiLogging))
    @loggings.map do |log|
      [].tap do |column|
        column << log.company_name
        column << log.end_point
        column << log.status
        column << (DateTime.strptime(log.timestamp, '%Q').strftime('%d %b %Y  %H:%M:%S') rescue nil)
        column << display_action(log.timestamp)
      end
    end
  end

  def count
    @count ||= SaplingApiLogging.count
  end

  def my_search loggings
    if params[:company_name].present?
      loggings = loggings.where('company_name': params[:company_name])
    end
    if params[:end_point].present?
      loggings = loggings.where('end_point.contains': params[:end_point])
    end
    if params[:data_received].present?
      loggings = loggings.where('data_received.contains': params[:data_received])
    end
    if params[:message].present?
      loggings = loggings.where('message.contains': params[:message])
    end
    if params[:status].present?
      params[:status] = successful_status if params[:status].eql?('Successful')
      params[:status] = unsuccessful_status if params[:status].eql?('Unsuccessful') 
      loggings = params[:status].class == String ? loggings.where(status: params[:status]) 
                                                  : loggings.where('status.in': params[:status])
    end
    if params[:date_from].present? && params[:date_to].present?
      loggings = loggings.where('timestamp.between':[params[:date_from].to_datetime.beginning_of_day.strftime('%Q'), params[:date_to].to_datetime.end_of_day.strftime('%Q')])
    elsif params[:date_from].present?
      loggings = loggings.where('timestamp.gt': params[:date_from].to_datetime.beginning_of_day.strftime('%Q'))
    elsif params[:date_to].present?
      loggings = loggings.where('timestamp.lt': params[:date_to].to_datetime.end_of_day.strftime('%Q'))
    end
    if params[:company_name].empty? && params[:status].empty?
      loggings = loggings.where(partition_id: '2')
    end
    loggings
  end

  def display_action id
    action_html = ("<button class='btn btn-default sm btn-font-sm'  onClick='show_api_logs(#{id})'>
        <i class='fa fa-info-circle'></i>
        </button>").html_safe
    action_html
  end

  def successful_status
    [200, 201, 202, 203, 204, 205, 206, 207, 226]
  end

  def unsuccessful_status
    [400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419,
      420, 421, 422, 423, 424, 425, 426, 500, 501, 502, 503, 504, 505, 506, 507, 510]
  end
end
