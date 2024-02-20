class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true, if: Proc.new { |c| c.request.format != 'application/json' }
  protect_from_forgery with: :null_session, prepend: true, if: Proc.new { |c| c.request.format == 'application/json' }
  rescue_from ActionController::UnknownFormat, with: :raise_not_found
  rescue_from ActionController::RoutingError, with:  :render_forbidden_error
  before_action :permit_params
  # before_action :set_paper_trail_whodunnit

  def raise_not_found
    render file: 'public/404.html'
  end

  def not_found(ex)
    render json: { errors: [Errors::NotFound.new(ex.message).error] }, status: :not_found
  end

  def info_for_paper_trail
    { ip: request.remote_ip, user_agent: request.user_agent }
  end

  def render_forbidden_error
    render file: 'public/403.html'
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
  
  def create_general_logging(company, action, data, type='Overall')
    @general_logging ||= LoggingService::GeneralLogging.new
    @general_logging.create(company, action, data, type)
  end

  def create_webhook_logging(company, integration_name, action, response_data, status, location, error=nil)
    @webhook_logging ||= LoggingService::WebhookLogging.new
    @webhook_logging.create(company, integration_name, action, response_data, status, location, error)
  end
end
