class ApiController < ActionController::API
  extend Responders::ControllerMethod

  include CanCan::ControllerAdditions
  include JsonResponder
  include IntegrationStatisticsManagement
  include CustomAuthentication

  require 'scrypt'

  before_action :permit_params
  before_action :set_paper_trail_whodunnit

  respond_to :json
  responders :json

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from CanCan::AccessDenied, with: :forbidden
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  before_action :set_default_subdomain
  before_action :set_cache_headers
  before_action :set_current_user_in_model
  before_action :set_last_active, if: proc { user_signed_in? && view_as_enabled && (session[:last_active] == nil || session[:last_active] < 1.hour.ago) }

  attr_reader :sapling_api, :token

  def set_current_user_in_model
    User.current = current_user
  end

  def log_request(status, message, location)
    create_sapling_api_logging(current_company, @api_token, request.url, params.to_json, status, message, location)

    if status == '200'
      log_success_api_calls_statistics(current_company)
    else
      log_failed_api_calls_statistics(current_company)
    end
  end

  def authorize_user
    if current_user.blank? || current_company.users.find_by(id: current_user.id).blank?
      head 403
    end

    if params[:user_id].present? && current_company.users.find_by(id: params[:user_id]).blank?
      head 403
    end
  end

  private

  def initialize_api
    @sapling_api = nil
    api_meta_data = { request: request, token: @api_token, api_key_fields: @api_key.selected_api_key_fields }
    if current_company.id == @company.id
      @sapling_api = SaplingApiService::Beta.new(current_company, api_meta_data)
    else
      create_sapling_api_logging(current_company, @api_token, request.url, params.to_hash, '401', 'Access denied', 'ApiController/initialize_api')
      return render html: "Access denied.", status: 401
    end
  end



  def authenticate_ids_server_request
    begin
      if params[:access_token]
        response = check_ids_access_token_expiry
        return render_response(response)
      end
    rescue StandardError => e
      create_sapling_api_logging(current_company, params[:access_token], request.url, params.to_hash, '401', {messages: ['Access denied', e.message]}.to_json, 'ApiController/authenticate_ids_request')
      return render html: "Access denied.", status: 401
    end
  end

  def authenticate
    begin
      authenticate_or_request_with_http_token do |api_token, options|
        access_token = JsonWebToken.decode(api_token)
        @api_token = api_token
        if access_token
          @company ||= Company.find_by(id: access_token['company_id'], account_state: 'active')
          @api_key ||= @company.api_keys.map {|api_key| api_key if SCrypt::Password.new(api_key.key) == api_token }.compact.first
          if @api_key.present? && @api_key.is_token_valid?
            @api_key.renew_api_key if @api_key.auto_renew
          else
            @company = errors.add(:token, 'Invalid token')
          end
        end
        @company ||= errors.add(:token, 'Invalid token') && nil
      end

      if !@company.try(:id).present?
        create_sapling_api_logging(current_company, @api_token, request.url, params.to_hash, '401', 'Access denied', 'ApiController/authenticate')
      end
    rescue Exception => e
      create_sapling_api_logging(current_company, @api_token, request.url, params.to_hash, '401', {messages: ['Access denied', e.message]}.to_json, 'ApiController/authenticate')
      return render html: "Access denied.", status: 401
    end
  end

  def set_last_active
    current_user.update_attribute(:last_active, Time.current)
    session[:last_active] = Time.current
  end

  def set_cache_headers
    response.headers["Cache-Control"] = "no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_in) { |u| u.permit(:email, :personal_email, :password, :provider, :uid) }
  end

  def authenticate_user!
    unauthorized unless current_user
  end

  def current_company
    @current_company ||= request.env['CURRENT_COMPANY']
  end

  def require_company!
    raise ActiveRecord::RecordNotFound unless current_company && current_company.active?
  end

  def verify_current_user_in_current_company!
    raise CanCan::AccessDenied if !current_user.present? || current_company.id != current_user.company_id
  end

  def set_default_subdomain
    SetUrlOptions.call(current_company, default_url_options)
  end

  def unauthorized
    render json: { errors: [Errors::Unauthorized.error] }, status: :unauthorized
  end

  def not_found(ex)
    render json: { errors: [Errors::NotFound.new(ex.message).error] }, status: :not_found
  end

  def forbidden(ex)
    render json: { errors: [Errors::Forbidden.new(ex.message).error] }, status: :forbidden
  end

  def unprocessable_entity(ex)
    render json: { errors: [Errors::UnprocessableEntity.new(ex.record).error] },
           status: :unprocessable_entity
  end

  def can_access_tasks(user_id)
    return if !user_id.present? || user_id.to_i == current_user.id || current_user.admin? || current_user.account_owner?

    user = User.find(user_id)
    raise CanCan::AccessDenied if user.id != current_user.id && user.manager_id != current_user.id
  end

  def can_access_documents(user_id)
    return if !user_id.present? || user_id.to_i == current_user.id || current_user.account_owner?

    user = User.find(user_id)
    if user.id != current_user.id
      return if (current_user.admin? && current_user.user_role.permissions['accessibility']['documents']) ||
        (user.manager_id == current_user.id && current_company.access_rights.where.not(role: 'manager', document_access_level: AccessRight.document_access_levels[:no_document_access]).present?)
    end

    raise CanCan::AccessDenied
  end

  def info_for_paper_trail
    { ip: request.remote_ip, user_agent: request.user_agent, company_name: current_company.nil?  ? nil : current_company.name }
  end

  begin
    Sapling::Application.configure do
      config.lograge.enabled = true

      config.lograge.custom_payload do |controller|

        user_id = nil
        user_id = controller.current_user.id if defined? controller.current_user.id

        {
          timestamp: DateTime.now,
          host: controller.request.host,
          user_id: user_id,
          client_ip: controller.request.remote_ip,
        }
      end
    end

  rescue Exception => e
    logger.info e.inspect
  end

  def permit_params
    params.permit!
  end

  def create_webhook_logging(company, integration_name, action, response_data, status, location, error=nil)
    @webhook_logging ||= LoggingService::WebhookLogging.new
    @webhook_logging.create(company, integration_name, action, response_data, status, location, error)
  end

  def create_sapling_api_logging company, api_key, end_point, data, status, message, location
    @sapling_api_logging ||= LoggingService::SaplingApiLogging.new
    @sapling_api_logging.create(company, api_key, end_point, data, status, message, location)
  end

  def create_integration_api_logging(company, integration_name, action, request, response, status)
    @integration_logging ||= LoggingService::IntegrationLogging.new
    @integration_logging.create(company, integration_name, action, request, response, status)
  end

  def create_general_logging(company, action, data, type='Overall')
    @general_logging ||= LoggingService::GeneralLogging.new
    @general_logging.create(company, action, data, type)
  end
  
  def view_as_enabled
    params[:viewAsEnabled] != 'true' && params[:action] != 'back_to_admin'
  end

  def check_ids_access_token_expiry
    response = IdsAuthentication::Events.new(current_company).check_expiry(params[:access_token])
    JSON.parse(response.body)
  end

  def access_denied
    create_sapling_api_logging(current_company, params[:'access_token'], request.url, params.to_hash, '401', 'Access denied', 'ApiController/authenticate_ids_request')
    render html: "Access denied.", status: 401
  end

  def enable_ids_notification
    render html: "Enable authentication through IDS for the company of user. access denied", status: 401
  end

  def render_response(response)
    if response['status'] == '200'
      @company = User.where('email ILIKE ? OR personal_email ILIKE ?', params[:email], params[:email]).take&.company
      @company && @company.ids_authentication_feature_flag ? @company : enable_ids_notification
    else
      access_denied
    end
  end
end
