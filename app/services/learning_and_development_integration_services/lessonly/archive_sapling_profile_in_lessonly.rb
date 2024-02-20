class LearningAndDevelopmentIntegrationServices::Lessonly::ArchiveSaplingProfileInLessonly
  attr_reader :company, :user, :integration

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :archive, to: :endpoint_service, prefix: :execute 

  def initialize(company, user, integration)
    @company = company
    @user = user
    @integration = integration
  end

  def perform
    archive
  end

  private
  
  def archive
    begin
      response = execute_archive(@integration, user.lessonly_id)
      parsed_response = JSON.parse(response.body)
      
      if response.ok?
        loggings('Success', response.code, parsed_response)
      else
        loggings('Failure', response.code, parsed_response)
      end
    rescue Exception => e
      loggings('Failure', 500, e.message)
    end
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Lessonly::Helper.new
  end

  def endpoint_service
    LearningAndDevelopmentIntegrationServices::Lessonly::Endpoint.new
  end

  def loggings status, code, parsed_response, request_data = {}, request_params = {}
    create_loggings(@company, 'Lessonly', code, "Archive user in lessonly - #{status}", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end
end