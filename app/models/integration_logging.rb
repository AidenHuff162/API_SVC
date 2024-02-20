class IntegrationLogging
  include Dynamoid::Document

  table name: ENV['INTEGRATION_LOGGING_TABLE_NAME'], key: :partition_id, read_capacity: 30, write_capacity: 10

  field :partition_id, :string
  field :company_id, :string
  field :company_name, :string
  field :company_domain, :string
  field :integration, :string
  field :action, :string
  field :request, :string
  field :response, :string
  field :status, :string
  range :timestamp, :string

  global_secondary_index name: :integration_company_name_timestamp_index,  hash_key: :company_name, range_key: :timestamp, projected_attributes: :all
  global_secondary_index name: :integration_timestamp_index,  hash_key: :integration, range_key: :timestamp, projected_attributes: :all
  global_secondary_index name: :integration_status_timestamp_index,  hash_key: :status, range_key: :timestamp, projected_attributes: :all
  
  INTEGRATION_NAMES = [
    'ADP Marketplace',
    'SAML',
    'NamelyHR',
    'Namely',
    'Hire',
    'GSuite',
    'GSheet',
    'JIRA',
    'Paylocity',
    'Okta',
    'OneLogin',
    'BambooHR',
    'Asana',
    'BSwift',
    'linked_in',
    'ADP Workforce Now - US',
    'ADP Workforce Now - CAN',
    'ADP Workforce Now',
    'Active Directory',
    'Fifteen Five',
    'Xero',
    'Deputy',
    'Workday',
    'Slack Notification',
    'Trinet',
    'Lattice',
    'Gusto',
    'Lessonly',
    'LearnUpon',
    'Paychex',
    'KallidusLearn',
    'Peakon',
    'TeamSpirit',
    'ServiceNow',
    'IdentityServer'
  ].freeze

  STAUSES = ['','Successful', 'Unsuccessful', 200, 201, 202, 203, 204, 205, 206, 207, 226, 300, 301, 302, 303, 304, 305, 306, 307, 400, 401, 402, 403, 404, 405, 406, 407,
    408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 500, 501, 502, 503, 504, 505, 506, 507, 510]
  
  def self.integration_names
    return ['', 'None'] + INTEGRATION_NAMES.sort_by { |a| a.downcase}
  end

  def self.statuses
    return STAUSES
  end
end
