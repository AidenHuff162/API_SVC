class CompanyMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    unless env['PATH_INFO'][%r{/assets/}]
      env['CURRENT_COMPANY'] = find_company(env)
    end
    if env['CURRENT_COMPANY'] && env['CURRENT_COMPANY'].inactive? && env['CURRENT_COMPANY'].migration_status == 'in_progress'
      return [302, { 'Content-Type' => 'application/json' }, []]
    elsif env['CURRENT_COMPANY'] && (env['CURRENT_COMPANY'].deleted_at || env['CURRENT_COMPANY'].inactive?)
      return [301, {'Content-Type' => 'application/json'}, []]
    else
      begin
        @app.call(env)
      rescue ActionController::BadRequest => error
        return [400, {'Content-Type' => 'application/json'}, [{ status: 400, message: I18n.t("api_notification.bad_request")}.to_json]]
      end
    end
  end

  private

  attr_reader :app

  def find_company(env)
    subdomain = find_subdomain(env)
    return if subdomain.blank?

    Company.find_by(subdomain: subdomain)
  end

  def find_subdomain(env)
    return unless env['SERVER_NAME'].match(/\.#{ENV['DEFAULT_HOST']}$/)

    env['SERVER_NAME'].remove(/\.#{ENV['DEFAULT_HOST']}$/)
  end
end
