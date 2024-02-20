class SaplingApiLogging
  include Dynamoid::Document
  table name: ENV['API_LOGGING_TABLE_NAME'], key: :partition_id, read_capacity: 20, write_capacity: 5

  field :partition_id, :string
  field :company_id, :string
  field :company_name, :string
  field :company_domain, :string
  field :data_received, :string
  field :end_point, :string
  field :location, :string
  field :message, :string
  field :status, :string
  range :timestamp, :string

  global_secondary_index name: :sapling_api_company_name_timestamp_index,  hash_key: :company_name, range_key: :timestamp, projected_attributes: :all
  global_secondary_index name: :sapling_api_status_timestamp_index,  hash_key: :status, range_key: :timestamp, projected_attributes: :all

end
