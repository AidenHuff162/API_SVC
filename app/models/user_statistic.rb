class UserStatistic < DataStatistic

  field :onboarded_user_ids, type: Array, default: Array.new
  field :loggedin_user_ids, type: Array, default: Array.new
  field :updated_user_ids, type: Array, default: Array.new

  validates_uniqueness_of :company_domain, scope: :record_collected_at

  def self.collection_name
    'user_statistics'
  end
end