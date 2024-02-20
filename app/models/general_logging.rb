class GeneralLogging
  include Dynamoid::Document

  table name: ENV['GENERAL_LOGGING_TABLE_NAME'], key: :partition_id, read_capacity: 20, write_capacity: 5

  field :partition_id, :string
  field :company_id, :string
  field :company_name, :string
  field :company_domain, :string
  field :action, :string
  field :log_type, :string
  field :result, :string
  range :timestamp, :string

  global_secondary_index name: :general_company_name_timestamp_index,  hash_key: :company_name, range_key: :timestamp, projected_attributes: :all
  global_secondary_index name: :log_type_timestamp_index,  hash_key: :log_type, range_key: :timestamp, projected_attributes: :all
end
