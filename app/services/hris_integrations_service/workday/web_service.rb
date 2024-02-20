require 'savon'
class HrisIntegrationsService::Workday::WebService
  include HrisIntegrationsService::Workday::Logs

  API_VERSION = { 'bsvc:version': 'v38.1' }.freeze

  attr_reader :company, :integration, :username, :password, :human_resource_wsdl, :staffing_wsdl

  def initialize(company_id)
    @company = Company.find_by(id: company_id)
    @integration = company&.get_integration('workday')
    return if integration.blank?

    set_credentials
  end

  def sync_workday
    integration.update_column(:synced_at, DateTime.now)
  end

  def prepare_request(operation, params, type='human_resource')
    wsdl = (type == 'human_resource') ? human_resource_wsdl : staffing_wsdl
    return unless can_request?(wsdl)

    send_request(wsdl, params, operation.to_sym)
  end

  private

  def send_request(wsdl, message, operation)
    client = Savon.client(get_call_params(wsdl))
    call_params = client_call_params(operation, message)
    begin
      response = client.call(operation, call_params)
      log_statistics(:success)
      response
    rescue StandardError => e
      log_statistics(:failed)
      raise e.message # use already implemented Exception Handling from where prepare_request is called
    end
  end

  def client_call_message_hash(message)
    { (message.is_a?(String) ? :xml : :message) => message } # We get string message, it means we need to send it as xml and not as message
  end

  def client_call_params(operation, message)
    { message_tag: convert_to_message_tag(operation), attributes: API_VERSION }.merge(client_call_message_hash(message))
  end

  def set_credentials
    credentials = integration.integration_credentials
    cred_fields = ['User Name', 'Password', 'Human Resource WSDL', 'Staffing WSDL']
    @username, @password, @human_resource_wsdl, @staffing_wsdl = cred_fields.map { |cred| credentials.by_name(cred).take&.value }
  end

  def can_request?(wsdl)
    username && password && wsdl
  end

  def get_call_params(wsdl)
    {
      wsdl: wsdl, log: true, log_level: :info, open_timeout: 1000, read_timeout: 1000,
      pretty_print_xml: true, env_namespace: :soapenv, namespace_identifier: :bsvc,
      convert_request_keys_to: :none, wsse_auth: [username, password], namespace: 'urn:com.workday/bsvc'
    }
  end

  def conflicted_operations_hash
    {
      change_government_i_ds: :Change_Government_IDs_Request,
      put_external_form_i_9: :'Put_External_Form_I-9_Request',
      maintain_contact_information: :Maintain_Contact_Information_for_Person_Event_Request
    }
  end

  def convert_to_message_tag(operation)
    conflicted_operations_hash[operation] || "#{operation.to_s.titleize.tr(' ', '_')}_Request".to_sym
  end
end
