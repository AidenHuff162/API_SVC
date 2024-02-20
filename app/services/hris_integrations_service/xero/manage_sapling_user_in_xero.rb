class HrisIntegrationsService::Xero::ManageSaplingUserInXero
  require 'openssl'

  attr_reader :user, :company, :xero
  
  delegate :fetch_integration, :refresh_token, :create_loggings, to: :helper_service
  
  def initialize(user)
    @user = user
    @company = user.company
    @xero = fetch_integration(company)
  end

  def perform(action, attributes = nil)
    unless action.present?
      create_loggings(@company, 'Xero', 404, 'Action missing', {message: 'Select action i.e. create, update etc'})
      return
    end

    unless refresh_token @xero
      create_loggings(@company, 'Xero', 404, "Xero credentials missing - #{action}", {message: 'Unable to refresh token'})
      return
    end

    execute(action, attributes)
    @xero.update_column(:synced_at, DateTime.now) if @xero.present?
  end

  private
 
  def log(status, action, result, request = nil)
    create_loggings(company, "Xero", status, action, result, request)
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end

  def execute(action, attributes)
    case action.downcase
    when 'create'
      create_profile
    when 'update'
      attributes.each do |field_name|
        update_profile(field_name)
      end
    when 'terminate'
      terminate_user
    end
  end

  def create_profile
    HrisIntegrationsService::Xero::CreateSaplingProfileInXero
    .new(user, @xero.reload).create_profile
  end

  def update_profile(field_name)
    HrisIntegrationsService::Xero::UpdateSaplingProfileInXero
    .new(user, @xero.reload).update_profile(field_name)
  end

  def terminate_user
    HrisIntegrationsService::Xero::UpdateSaplingProfileInXero
    .new(user, @xero.reload).terminate_user
  end
end