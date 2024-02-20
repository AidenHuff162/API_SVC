class RoiManagementServices::IntegrationStatistics
  attr_reader :attributes, :method_name, :method_action

  def initialize(attributes, method_name, method_action)
    @attributes = attributes
    @method_name = method_name
    @method_action = method_action
  end

  def perform
    return unless @method_name.present? && @method_action.present? && Rails.env.development?.blank? && Rails.env.staging?.blank?
    begin
      case @method_name
      when 'manage_ats_stats'
        manage_ats_stats
      when 'manage_hris_stats'
        manage_hris_stats
      when 'manage_api_calls_stats'
        manage_api_calls_stats
      end
    rescue Exception => e
      puts '==================='
      puts e.inspect
      puts '==================='
    end
  end

  private

  def fetch_company(company_id)
    Company.find_by_id(company_id)
  end

  def date_in_company_timezone(company)
    Date.today.in_time_zone(company.time_zone)
  end

  def create(company_id, company_domain, count, date, column_name)
    IntegrationStatistic.create!(company_id: company_id, company_domain: company_domain, record_collected_at: date).push("#{column_name}": count)
  end

   def update(integration_statistic, count, column_name)
    return unless integration_statistic.present?

    integration_statistic.push("#{column_name}": count)
  end

  def create_or_update(company_id, count, column_name)
    company = fetch_company(company_id)
    return unless company.present? && count.present? && column_name.present?

    date = date_in_company_timezone(company)
    integration_statistic = IntegrationStatistic.of_specific_day(company_id, company.domain, date)
    integration_statistic.blank? ? create(company_id, company.domain, count, date, column_name) : update(integration_statistic, count, column_name)
  end

  def manage_ats_stats
    column_name = (@method_action == 'success') ? 'ats_success_count' : 'ats_failed_count'
    create_or_update(@attributes[:company_id], @attributes[:count], column_name)
  end

  def manage_hris_stats
    column_name = (@method_action == 'success') ? 'hris_success_count' : 'hris_failed_count'
    create_or_update(@attributes[:company_id], @attributes[:count], column_name)
  end

  def manage_api_calls_stats
    column_name = (@method_action == 'success') ? 'api_calls_success_count' : 'api_calls_failed_count'
    create_or_update(@attributes[:company_id], @attributes[:count], column_name)
  end
end
