class HrisIntegrations::Xero::RemoveXeroConnection
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(company_id, refresh_token, connection_id)
    company = Company.find_by(id: company_id)
    return unless [company, refresh_token, connection_id].all?

    ::HrisIntegrationsService::Xero::RemoveXeroConnection.new(company).remove_xero_connection(refresh_token, connection_id)
  end
end