ActionMailer::Base.default_url_options[:host] = ENV['DEFAULT_HOST']

ActionMailer::Base.delivery_method =
  case Rails.env
    when 'staging', 'production', 'demo', 'fuse' then
      :smtp
    when 'development'
      :letter_opener
    else
      :test
  end

ActionMailer::Base.smtp_settings = {
  address:              ENV['SES_SMTP_ADDRESS'] || 'email-smtp.us-east-1.amazonaws.com',
  enable_starttls_auto: true,
  authentication:       :login,
  port:                 465,
  user_name:            ENV['SES_SMTP_USERNAME'],
  password:             ENV['SES_SMTP_PASSWORD'],
  tls:                  ENV['SMTP_TLS'].present?
}
