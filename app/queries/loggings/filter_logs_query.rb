module Loggings
  class FilterLogsQuery < ApplicationService
    attr_reader :filters, :loggings_mapper, :loggings_type

    def initialize(args)
      @filters = args[:filters]
      @loggings_mapper = args[:loggings_mapper]
      @loggings_type = args[:loggings_type]
      @loggings = args[:loggings]
    end

    def call
      fetch_logging_based_on_filters
      fetch_loggings_between_date_range
      filtering_partition_logs
    end

    def fetch_logging_based_on_filters
      loggings_mapper.reject! { |_key, value| value.blank? }

      loggings_mapper.each do |key, _value|
        @loggings = send("filter_by_#{key}")
      end
    end

    def filter_by_company_name
      @loggings.where('company_name': filters[:company_name])
    end

    def filter_by_end_point
      @loggings.where('end_point.contains': filters[:end_point])
    end

    def filter_by_data_received
      @loggings.where('data_received.contains': filters[:data_received])
    end

    def filter_by_message
      @loggings.where('message.contains': filters[:message])
    end

    def filter_by_status
      @loggings.where('status': filters[:status])
    end

    def filter_by_integration
      @loggings.where('integration': filters[:integration])
    end

    def filter_by_error_message
      @loggings.where('error_message.contains': filters[:error_message])
    end

    def filter_by_actions
      @loggings.where('action.contains': filters[:actions])
    end

    def fetch_loggings_between_date_range
      return filter_by_date_from_to if filters[:date_from].present? && filters[:date_to].present?
      return filter_by_date_from if filters[:date_from].present?
      return filter_by_date_to if filters[:date_to].present?

    end

    def filter_by_date_from
      @loggings = @loggings.where('timestamp.gt': filters[:date_from].to_datetime.beginning_of_day.strftime('%Q'))
    end

    def filter_by_date_to
      @loggings = @loggings.where('timestamp.lt': filters[:date_to].to_datetime.end_of_day.strftime('%Q'))
    end

    def filter_by_date_from_to
      @loggings = @loggings.where('timestamp.between': [filters[:date_from].to_datetime.beginning_of_day.strftime('%Q'),
                                           filters[:date_to].to_datetime.end_of_day.strftime('%Q')])
    end

    def filtering_partition_logs  
      is_data_empty = filters[:company_name].empty? && filters[:status].empty?
      filter_partition_logs_by_logging_type?(is_data_empty) && (@loggings != loggings_type.constantize) ? @loggings.where(partition_id: '2') : @loggings
    end

    def filter_partition_logs_by_logging_type?(is_data_empty)
      ((is_data_empty && loggings_type == 'SaplingApiLogging') ||
      (%w[IntegrationLogging WebhookLogging].include?(loggings_type) &&
      is_data_empty && filters[:integration].empty?))
    end

  end
end