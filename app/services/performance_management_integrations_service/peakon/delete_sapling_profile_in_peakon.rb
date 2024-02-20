class PerformanceManagementIntegrationsService::Peakon::DeleteSaplingProfileInPeakon
  attr_reader :company, :user, :integration

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :delete, to: :endpoint_service, prefix: :execute 

  def initialize(company, user, integration)
    @company = company
    @user = user
    @integration = integration
  end

  def perform
    delete
  end

  private

  def delete
    begin  
      response = execute_delete(@integration, user)
      if response.no_content?
        loggings('Success', response.code, response)
      else
        loggings('Failure', response.code, response)
      end
    rescue Exception => e
      loggings('Failure', 500, e.message)
    end
  end

  def helper_service
    PerformanceManagementIntegrationsService::Peakon::Helper.new
  end

  def endpoint_service
    PerformanceManagementIntegrationsService::Peakon::Endpoint.new
  end

  def loggings status, code, response
    create_loggings(@company, 'Peakon', code, "Delete user in Peakon - #{status}", {response: response}, {data: @user.peakon_id})
    log_statistics(status.downcase, @company)
  end
end

