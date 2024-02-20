class LearningAndDevelopmentIntegrationServices::Lessonly::ManageLessonlyProfileInSapling
  attr_reader :company, :integration

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, to: :helper_service

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
  end

  def perform
    @integration.in_progress!

    unless is_integration_valid?(@integration)
      @integration.failed!
      create_loggings(@company, 'Lessonly', 404, "Lessonly credentials missing - Update from Lessonly")
      return
    end

    execute
    @integration.succeed!
    @integration.update_column(:synced_at, DateTime.now)
  end

  private
  
  def update_profile
    ::LearningAndDevelopmentIntegrationServices::Lessonly::UpdateLessonlyProfileInSapling
      .new(@company, @integration).update
  end

  def execute
    update_profile
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Lessonly::Helper.new
  end
end