class LearningAndDevelopmentIntegrationServices::Kallidus::ManageKallidusProfileInSapling
  attr_reader :company, :integration, :user_id

  delegate :fetch_integration, :is_integration_valid?, to: :helper_service

  def initialize(company, user_id = nil)
    @company = company
    @integration = fetch_integration(@company)
    @user_id = user_id
  end

  def perform
    @integration.in_progress!
    unless is_integration_valid?(@integration)
      @integration.failed!
      create_loggings(@company, 'KallidusLearn', 404, "KallidusLearn credentials missing - Update from KallidusLearn")
      return
    end

    execute
    @integration.update_columns(sync_status: IntegrationInstance.sync_statuses[:succeed], synced_at: DateTime.now)
  end

  private

  def update_profile
    ::LearningAndDevelopmentIntegrationServices::Kallidus::UpdateKallidusProfileInSapling
      .new(@company, @integration, @user_id).update
  end

  def execute
    update_profile
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Kallidus::Helper.new
  end

end