class IntegrationStatistic < DataStatistic

  field :ats_success_count, type: Array, default: Array.new
  field :ats_failed_count, type: Array, default: Array.new
  field :hris_success_count, type: Array, default: Array.new
  field :hris_failed_count, type: Array, default: Array.new
  field :api_calls_success_count, type: Array, default: Array.new
  field :api_calls_failed_count, type: Array, default: Array.new

  validates_uniqueness_of :company_domain, scope: :record_collected_at

  def self.collection_name
    'integration_statistics'
  end
end