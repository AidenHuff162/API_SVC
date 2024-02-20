module WebhookEventServices
  class CreateJobDetailsChangedEventsService
    attr_reader :company, :user_attributes, :params, :data, :table_name, :effective_date, :date_format
    
    delegate :fetch_users, :get_values_changed, :format_date, to: :helper_service
    delegate :create, to: :logging, prefix: :logs

    def initialize(company, user_attributes, params, data, table_name, effective_date)
      @company = company
      @user_attributes = user_attributes
      @params = params
      @data = data&.with_indifferent_access
      @table_name = table_name
      @effective_date = effective_date
      @date_format = company.get_date_format
    end

    def perform
      create_webhook_events
    end

    private

    def create_webhook_events
      values_changed = params.empty?.blank? ? get_values_changed(company, [nil, ''], user_attributes, params, false, table_name, effective_date) : []
      values_changed = values_changed + custom_values_changed if data.present?
      logs_create(company, 'Trigger Webhooks for Job Details Changed', {changed_values: values_changed.inspect, user_attributes: user_attributes.inspect, params: params.inspect, data: data.inspect}, 'CustomTables')
      WebhookEvents::CreateWebhookEventsJob.perform_async(company.id, {type: 'job_details_changed', values_changed: values_changed, triggered_for: user_attributes['id']}) if values_changed.present?
    end

    def custom_values_changed
      values_changed = []
      (0..data[:field_names].count).to_a.try(:each) do |key|
        next if data[:field_names][key] == 'Effective Date'

        if data[:field_type] == 'date'
          new_value, old_value = format_date(date_format, data[:new_values][key]), format_date(date_format, data[:old_values][key])
        else
          new_value, old_value = data[:new_values][key], data[:old_values][key]
        end

        value_changed = { field_id: data[:api_field_ids][key], values: { tableName: table_name, fieldName: data[:field_names][key].titleize, oldValue: old_value, newValue: new_value } } if old_value != new_value
        
        if value_changed.present?
          value_changed[:values].merge!({effectiveDate: format_date(date_format, effective_date)}) if effective_date.present?
          values_changed << value_changed
        end
      end
      return values_changed
    end

    def helper_service
      WebhookEventServices::HelperService.new
    end

    def logging
      LoggingService::GeneralLogging.new
    end
  end
end