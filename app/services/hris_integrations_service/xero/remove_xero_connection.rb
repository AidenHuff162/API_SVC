class HrisIntegrationsService::Xero::RemoveXeroConnection
  attr_reader :company
  delegate :create_loggings, :refresh, to: :helper_service

  def initialize(company)
    @company = company
  end

  def remove_xero_connection(refresh_token, connection_id)
    begin
      token_response = refresh(refresh_token)

      if token_response.ok?
        access_token = JSON.parse(token_response.body)['access_token']
        
        response = HTTParty.delete("https://api.xero.com/connections/#{connection_id}",headers: { 'Authorization' => 'Bearer ' + access_token })

        if response.no_content?
          log(response.code, 'Remove Connection in Xero - SUCCESS', { connection_id: connection_id, response: response.to_s, token_response: token_response.to_s })
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          log(response.code, 'Remove Connection in Xero - Failure', { connection_id: connection_id, response: response.to_s, token_response: token_response.to_s })
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      end
    rescue Exception => e
      log(500, 'Remove Connection in Xero - Failure', { message: e.message, connection_id: connection_id, token_response: token_response.to_s })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  private
  
  def log(status, action, result, request = nil)
    create_loggings(company, "Xero", status, action, result, request)
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end
end
