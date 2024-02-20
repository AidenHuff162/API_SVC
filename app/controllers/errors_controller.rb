class ErrorsController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true, if: Proc.new { |c| c.request.format != 'application/json' }
  protect_from_forgery with: :null_session, prepend: true, if: Proc.new { |c| c.request.format == 'application/json' }
  
  def not_found
    render "not_found"
  end

  def forbidden_error
    render file: 'public/403.html'
  end
end
