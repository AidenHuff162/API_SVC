class SetUrlOptions
  def self.call(current_company, *option_hashes)
    option_hashes += [
      Rails.application.config.action_mailer.default_url_options,
      ActionMailer::Base.default_url_options,
      Rails.application.routes.default_url_options
    ]

    option_hashes.compact.each { |options| new(current_company, options).call }
  end

  def initialize(current_company, options)
    @current_company = current_company
    @options = options
  end

  def call
    if current_company.nil?
      options.delete(:subdomain)
      options[:host] = ENV['DEFAULT_HOST']
    elsif current_company.domain.blank?
      options[:subdomain] = current_company.subdomain
      options[:host] = ENV['DEFAULT_HOST']
    else
      options.delete(:subdomain)
      options[:host] = current_company.domain
    end
  end

  private

  attr_reader :current_company, :options
end
