class RoiEmailManagementServices::CalculateWeeklyStatistics
  attr_reader :company, :begin_date, :end_date

  def initialize(company, date)
    @company = company
    @begin_date = date.at_beginning_of_week
    @end_date = date.at_end_of_week
  end

  def perform
    fetch_statistics
  end

  private

  def fetch_statistics
    statistics = {}

    statistics[:signed_documents_count] = fetch_documents_statistics
    statistics[:assigned_tasks_count] = fetch_task_statistics

    if @company.enabled_time_off.present?
      statistics[:assigned_ptos_count] = fetch_ptos_statistics
    end

    user_statistics = fetch_user_statistics
    statistics.merge!(user_statistics) if user_statistics.present?

    integration_statistics = fetch_integration_statistics
    statistics.merge!(integration_statistics) if integration_statistics.present?

    statistics[:live_integrations_count] = fetch_live_integrations_statistics

    return statistics
  end

  def fetch_documents_statistics
    PaperworkRequest.span_based_signed_documents(@company.id, @begin_date, @end_date).count
  end

  def fetch_task_statistics
    TaskUserConnection.span_based_assigned_tasks(@company.id, @begin_date, @end_date).count
  end

  def fetch_ptos_statistics
    PtoRequest.span_based_assigned_ptos(@company.id, @begin_date, @end_date).count
  end

  def fetch_user_statistics
    user_statistics = UserStatistic.of_specific_week(@company.id, @company.domain, @begin_date)
    if user_statistics.present?
      return {
        logged_in_users_count: user_statistics.pluck(:loggedin_user_ids).flatten.compact.uniq.count,
        records_updated_count: user_statistics.pluck(:updated_user_ids).flatten.compact.count,
        onboarded_users_count: user_statistics.pluck(:onboarded_user_ids).flatten.compact.uniq.count
      }
    end
    
    return {logged_in_users_count: 0, records_updated_count: 0, onboarded_users_count: 0}
  end

  def fetch_integration_statistics
    integration_statistics = IntegrationStatistic.of_specific_week(@company.id, @company.domain, @begin_date)
    if integration_statistics.present?
      return { 
        api_call_processed_count: integration_statistics.pluck(:ats_success_count, :hris_success_count, :api_calls_success_count).flatten.compact.inject(0, :+)
      }
    end

    return {api_call_processed_count: 0}
  end

  def fetch_live_integrations_statistics
    @company.integrations.count
  end
end