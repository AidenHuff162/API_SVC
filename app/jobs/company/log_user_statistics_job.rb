class Company::LogUserStatisticsJob
  include Sidekiq::Worker

  def perform(ids, type)
    ::RoiManagementServices::UserStatistics.new(ids.with_indifferent_access, type, 'create_or_update').perform
  end
end
