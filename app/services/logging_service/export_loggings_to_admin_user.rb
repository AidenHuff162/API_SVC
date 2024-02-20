module LoggingService
  class ExportLoggingsToAdminUser < ApplicationService
    include LoggingService::LoggingHashes 
    include LoggingService::LoggingConstants
    attr_reader :loggings_type, :user_id, :filters

    def initialize(args)
      @loggings_type = args[:loggings_type]
      @filters = JSON.parse(args[:filters]).with_indifferent_access
      @user_id = args[:user_id]
      @csv_logs = []
    end

    def call
      export_loggings
    end

    private

    def export_loggings
      user = AdminUser.find_by(id: user_id)
      return unless user

      prepare_loggings(loggings_type)
      csv_file = create_csv_file(@csv_logs.compact, loggings_type)
      
      UserMailer.send_loggings_csv_mail(user, { file: csv_file, file_name: loggings_type }).deliver_now!
      File.delete(csv_file) if csv_file.present?
    end

    def prepare_loggings(loggings_type)
      loggings = search_loggings_based_on_filters(loggings_type)
      fetch_loggings(loggings, loggings_type)
    end

    def search_loggings_based_on_filters(loggings_type)
      loggings = loggings_mapper[loggings_type][:loggings].constantize
      args = { filters: filters, loggings_mapper: loggings_mapper[loggings_type][:hash], loggings_type: loggings_type, loggings: loggings }
      Loggings::FilterLogsQuery.call(args)
    end

    def fetch_loggings(loggings, loggings_type)
      total_count = 0;
      loop do
        loggings = loggings.record_limit(LOGGINGS_FETCH_LIMIT).start(@last_evaluated_key).scan_index_forward(false)
        @last_evaluated_key = nil

        logs, @last_evaluated_key = compiling_logs(loggings)
        logs_count = logs.length
        break if logs_count <= 0 || total_count >= CSV_LOGGINGS_LIMIT

        total_count += logs_count
        create_csv_loggings(loggings_type, logs)
        break if logs_count < LOGGINGS_FETCH_LIMIT
      end
    end

    def compiling_logs(loggings)
      logs = [];
      last_evaluated_key = nil
      begin
        retries ||= 0
        loggings.find_by_pages.each do |page, pointer|
          page.each { |row| logs << row }
          last_evaluated_key = pointer[:last_evaluated_key]
        end
      rescue Aws::DynamoDB::Errors::ProvisionedThroughputExceededException
        if (retries += 1) < 5
          sleep(retries)
          retry
        end
      end
      [logs, last_evaluated_key]
    end

    def format_date(log)
      DateTime.strptime(log.timestamp, '%Q').strftime('%d %b %Y  %H:%M:%S')
    rescue StandardError
      nil
    end

    def create_csv_loggings(loggings_type, logs)
      logs.try(:each) do |log, _index|
        csv_log = []
        csv_log << [log.company_name, log.end_point, log.status, format_date(log)] if loggings_type == 'SaplingApiLogging'
        csv_log << [log.company_name, log.integration, log.action, log.status, format_date(log)] if %w[IntegrationLogging
                                                                                                       WebhookLogging].include?(loggings_type)
        @csv_logs.push(csv_log&.flatten)
      end
    end

    def csv_headers(loggings_type)
      headers_list = []
      headers_list = ['Company Name', 'End Point', 'Status', 'Created At'] if loggings_type == 'SaplingApiLogging'
      headers_list = ['Company Name', 'Integration', 'Action', 'Status', 'Created At'] if %w[IntegrationLogging
                                                                                             WebhookLogging].include?(loggings_type)
      headers_list.map { |header| header.present? ? header.titleize : '' }
    end

    def create_csv_file(csv_logs, loggings_type)
      csv_file = File.join(FILE_STORAGE_PATH, "#{loggings_type}_csv_#{rand(1000)}.csv")
      CSV.open(csv_file, 'w', write_headers: true, headers: csv_headers(loggings_type)) do |writer|
        writer.to_io.write "\uFEFF"
        csv_logs.each { |csv_log| writer << csv_log }
      end
      csv_file
    end

  end
end
