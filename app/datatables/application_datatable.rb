class ApplicationDatatable
  delegate :params, to: :@view
  delegate :link_to, :fa_icon, :integration_path, to: :@view

  def initialize(view, session, log_type=nil)
    @view = view
    @session = session
    @log_type = log_type
  end

  def as_json(options = {})
    {
      data: data,
      recordsTotal: count,
      recordsFiltered: @last_evaluated_key.nil? ? (@logs_count + params['start'].to_i) : count
    }
  end

  def fetch_loggings loggings
    page = ((params['start'].to_i/params['length'].to_i) + 1).to_s
    start = @session[:logging_pagination][page] rescue nil
    
    loggings = loggings.record_limit(params['length'].to_i).start(start).scan_index_forward(false)
    
    logs = []
    @last_evaluated_key = nil
    
    begin
      retries ||= 0
      loggings.find_by_pages.each do |p, m|
        p.each { |l|  logs << l}
        @last_evaluated_key = m[:last_evaluated_key]
        update_session @last_evaluated_key, page
      end
    rescue Aws::DynamoDB::Errors::ProvisionedThroughputExceededException 
      if (retries += 1) < 5
        sleep(retries)
        retry
      end
    end

    @logs_count = logs.length
    
    logs
  end

  def update_session last_evaluated_key, page
    @session['logging_pagination'] = {} if @session['logging_pagination'].nil?
    if @session['logging_pagination']["#{page.to_i + 1}"].present?
      @session['logging_pagination']["#{page.to_i + 1}"] = last_evaluated_key
    else
      @session['logging_pagination'].merge!({"#{page.to_i + 1}": last_evaluated_key})
    end
    @session['logging_pagination'].each {|l| @session['logging_pagination'][l[0]] = nil if l[0].to_s.to_i > (page.to_i + 1)}
  end
end
