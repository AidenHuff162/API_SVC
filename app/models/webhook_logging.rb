class WebhookLogging
  include Dynamoid::Document

  table name: ENV['WEBHOOK_LOGGING_TABLE_NAME'], key: :partition_id, read_capacity: 20, write_capacity: 5

  field :partition_id, :string
  field :company_id, :string
  field :company_name, :string
  field :company_domain, :string
  field :integration, :string
  field :action, :string
  field :status, :string
  field :data_received, :string
  field :error_message, :string
  field :location, :string
  range :timestamp, :string

  global_secondary_index name: :webhook_company_name_timestamp_index,  hash_key: :company_name, range_key: :timestamp, projected_attributes: :all
  global_secondary_index name: :webhook_integration_timestamp_index,  hash_key: :integration, range_key: :timestamp, projected_attributes: :all
  global_secondary_index name: :webhook_status_timestamp_index,  hash_key: :status, range_key: :timestamp, projected_attributes: :all

  WEBHOOK_NAMES = [
    'Jira',
    'Greenhouse',
    'Lever',
    'Smart Recruiters',
    'BambooHR',
    'Namely',
    'ADP_WFN',
    'Workable',
    'JazzHR',
    'Hire Bridge',
    'Custom ATS - breezy',
    'Fountain'
  ]

  def self.webhook_names
    return ['', 'None'] + WEBHOOK_NAMES.sort_by { |a| a.downcase}
  end
end
