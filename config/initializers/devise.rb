Devise.setup do |config|
  config.warden do |manager|
    manager.default_strategies(:scope => :user).unshift :two_factor_authenticatable
  end

  config.warden do |manager|
    manager.default_strategies(:scope => :admin_user).unshift :two_factor_authenticatable
  end

  config.email_regexp = /\A[^@\s]+@([^@\s]+\.)+[^@\W]+\z/
  config.navigational_formats = [:html, :json]
  config.authentication_keys = [:email]
  config.mailer = 'CustomDeviseMailer'
  config.secret_key = ENV['SECRET_KEY_BASE']

  config.lock_strategy = :failed_attempts
  config.last_attempt_warning = true
  config.unlock_strategy = :time
  config.maximum_attempts = Sapling::Application::LOGIN_ATTEMPTS[:user]
  config.unlock_in = 10.minutes

  config.password_length = 8..128
end
