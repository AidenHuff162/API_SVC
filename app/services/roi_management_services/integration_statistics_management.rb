class RoiManagementServices::IntegrationStatisticsManagement

  def log_success_webhook_statistics(company)
    return unless Rails.env.test?.blank?

    ::RoiManagementServices::IntegrationStatistics.new({company_id: company.id, count: 1}, 'manage_ats_stats', 'success').perform
  end

  def log_failed_webhook_statistics(company)
    return unless Rails.env.test?.blank?

    ::RoiManagementServices::IntegrationStatistics.new({company_id: company.id, count: 1}, 'manage_ats_stats', 'failed').perform
  end

  def log_success_api_calls_statistics(company)
    return unless Rails.env.test?.blank?

    ::RoiManagementServices::IntegrationStatistics.new({company_id: company.id, count: 1}, 'manage_api_calls_stats', 'success').perform
  end

  def log_failed_api_calls_statistics(company)
    return unless Rails.env.test?.blank?

    ::RoiManagementServices::IntegrationStatistics.new({company_id: company.id, count: 1}, 'manage_api_calls_stats', 'failed').perform
  end

  def log_success_hris_statistics(company, count = 1)
    return unless Rails.env.test?.blank?

    ::RoiManagementServices::IntegrationStatistics.new({company_id: company.id, count: count}, 'manage_hris_stats', 'success').perform
  end

  def log_failed_hris_statistics(company, count = 1)
    return unless Rails.env.test?.blank?

    ::RoiManagementServices::IntegrationStatistics.new({company_id: company.id, count: count}, 'manage_hris_stats', 'failed').perform
  end
end