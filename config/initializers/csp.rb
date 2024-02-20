SecureHeaders::Configuration.default do |config|
  config.csp = {
    default_src: %w(*),
    img_src: %w(* 'self' data: https:),
    font_src: %w(* 'self' data: https:),
    script_src: %w(* 'unsafe-inline' 'unsafe-eval'),
    style_src: %w(* 'unsafe-inline' 'unsafe-eval'),
    connect_src: %w(* 'self' data: https:)
  }
  config.csp_report_only = {
    default_src: %w(*),
    img_src: %w(* 'self' data: https:),
    font_src: %w(* 'self' data: https:),
    script_src: %w(* 'unsafe-inline' 'unsafe-eval'),
    style_src: %w(* 'unsafe-inline' 'unsafe-eval'),
    connect_src: %w(* 'self' data: https:),
    report_uri: %w(https://sapling.report-uri.com/r/d/csp/reportOnly),
    report_only: true
  }
end
