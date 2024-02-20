class GeneralDatatable < ApplicationDatatable
  delegate  to: :@view

  private

  def data
    @loggings = fetch_loggings(my_search(GeneralLogging))
    @loggings.map do |log|
      [].tap do |column|
        column << log.company_name
        column << log.action
        column << log.result
        column << (DateTime.strptime(log.timestamp, '%Q').strftime('%d %b %Y  %H:%M:%S') rescue nil)
        column << display_action(log.timestamp)
      end
    end
  end

   def count
    @count ||= GeneralLogging.count
  end

  def my_search loggings
    loggings = loggings.where(log_type: @log_type)
    if params[:company_name].present?
      loggings = loggings.where('company_name': params[:company_name])
    end
    if params[:result].present?
      loggings = loggings.where('result.contains': params[:result])
    end
    if params[:actions].present?
      loggings = loggings.where('action.contains': params[:actions])
    end
    if params[:module].present?
      loggings = loggings.where('module.contains': params[:module])
    end
    if params[:date_from].present? && params[:date_to].present?
      loggings = loggings.where('timestamp.between':[params[:date_from].to_datetime.beginning_of_day.strftime('%Q'), params[:date_to].to_datetime.end_of_day.strftime('%Q')])
    elsif params[:date_from].present?
      loggings = loggings.where('timestamp.gt': params[:date_from].to_datetime.beginning_of_day.strftime('%Q'))
    elsif params[:date_to].present?
      loggings = loggings.where('timestamp.lt': params[:date_to].to_datetime.end_of_day.strftime('%Q'))
    end
    loggings
  end

  def display_action id
    action_html = ("<button class='btn btn-default sm btn-font-sm' onClick='show_general_logs(#{id})' >
        <i class='fa fa-info-circle'></i>
        </button>").html_safe
    action_html
  end
end
