class TimeConversionService
  attr_reader :company

  def initialize(company)
    @company = company
  end

  def perform(time, short_format = false)
    time = time.try(:to_date)
    return format_time(time, short_format)
  end

  def format_pto_dates arg1, arg2
    format_dates arg1, arg2
  end

  private

  def format_time(time, short_format)
    date_format = company.date_format.downcase rescue 'mm/dd/yyyy'

    case date_format
    when 'mm/dd/yyyy'
      short_format ? time.strftime('%m/%d/%y') : time.strftime('%m/%d/%Y')
    when 'dd/mm/yyyy'
      short_format ? time.strftime('%d/%m/%y'): time.strftime('%d/%m/%Y')
    when 'yyyy/mm/dd'
      short_format ? time.strftime('%y/%m/%d') : time.strftime('%Y/%m/%d')
    when 'mmm dd, yyyy'
      time.strftime('%b %d, %Y')
    else
      time
    end
  end

  def format_dates arg1, arg2
    format = @company.date_format
    if format == "MM/dd/yyyy"
      format = "%m/%d/%Y"
    elsif format == "dd/MM/yyyy"
      format = "%d/%m/%Y"
    elsif format == "MMM DD, YYYY"
      format = "%b %d, %Y"
    else
      format = "%y/%m/%d"
    end
    if arg1.strftime(format) == arg2.strftime(format)
      arg1.strftime(format)
    else
      arg1.strftime(format) + " - " +  arg2.strftime(format)
    end
  end
end
