class SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling
  attr_reader :build_param_service, :sapling_user, :one_login_integration

  delegate :create, :update, to: :one_login_user

  def initialize(user_id)
    return unless user_id.present?

    @sapling_user = fetch_sapling_user(user_id)
    @one_login_integration = sapling_user.company.integration_instances.find_by(api_identifier: 'one_login', state: :active)
    return unless one_login_integration.present?

    @build_param_service = SsoIntegrationsService::OneLogin::BuildParams.new(sapling_user, one_login_integration)
  end

  def create_one_login_user
    return unless sapling_user.present? && !sapling_user.one_login_id.present?

    begin
      data = build_param_service.create_params
      response = create(data)
      sapling_user.update_column(:one_login_id, response["data"][0]["id"]) if response.present? && !response["status"]["error"]
      one_login_integration.update_column(:synced_at, DateTime.now)
    rescue Exception => e
      response = {}
      response.merge!({"message": e.message, "status": {"code": 500}}.with_indifferent_access)
    end

    generate_logs('Create User - OneLogin', response, data, response["status"]["code"]) if response.present?
    create_one_login_user_custom_attributes if response.present? && !response["status"]["error"]
  end

  def create_one_login_user_custom_attributes
    begin
      data = build_param_service.build_custom_attributes
      response = update(data, sapling_user.one_login_id)
      one_login_integration.update_column(:synced_at, DateTime.now)
    rescue Exception => e
      response = {}
      response.merge!({"message": e.message, "status": {"code": 500}}.with_indifferent_access)
    end
    generate_logs('Create User custom attributes - OneLogin', response, data, response["status"]["code"])
  end

  def update_one_login_user(fields)
    return unless sapling_user.present? && fields.present?

    begin
      data = {}

      fields.each do |field|
        build_param_service.update_params(field, data)
      end
      return unless data.present?
      response = update(data, sapling_user.one_login_id)
      one_login_integration.update_column(:synced_at, DateTime.now)
    rescue Exception => e
      response = {}
      response.merge!({"message": e.message, "status": {"code": 500}}.with_indifferent_access)
    end

    generate_logs('Update User - OneLogin', response, data, response["status"]["code"]) unless response == "update disabled" || response.blank?
  end

  private

  def fetch_sapling_user(user_id)
    User.find_by_id(user_id)
  end

  def one_login_user
    SsoIntegrationsService::OneLogin::User.new sapling_user.company
  end

  def generate_logs(action, response, data, status = nil)
    LoggingService::IntegrationLogging.new.create(sapling_user.company, 'OneLogin', action, {request: data}, {result: response}, status)
  end
end
