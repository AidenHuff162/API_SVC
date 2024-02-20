class SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling
  attr_reader :company, :integration

  delegate :log, :fetch_access_token, to: :helper_service

  def initialize(company)
    @company = company
    @integration = helper_service.one_login_api
  end

  def perform
    unless fetch_access_token.present?
      log(404, "Onelogin credentials missing - Update from Onelogin", {message: 'Failed to fecth access token'}, {error: "Onelogin credentials missing - Update from Onelogin"})
      return
    end

    execute
    integration.update_column(:synced_at, DateTime.now) if integration.present?
  end

  private
  
  def update_profile
    ::SsoIntegrationsService::OneLogin::UpdateSaplingUserFromOneloginJob
      .new(@company).update
  end

  def execute
    update_profile
  end

  def helper_service
    ::SsoIntegrationsService::OneLogin::User.new company
  end
end