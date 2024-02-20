class DataStatistic
  include Mongoid::Document
  include Mongoid::Timestamps

  field :company_id, type: Integer
  field :company_domain, type: String
  field :record_collected_at, type: Date

  scope :of_company, -> (company_id, company_domain){ where(company_id: company_id, company_domain: company_domain) }

  scope :of_today, -> (company_id, company_domain){ where(record_collected_at: Date.today, company_id: company_id, company_domain: company_domain).limit(1) }
  scope :of_specific_day, -> (company_id, company_domain, date){ where(record_collected_at: date, company_id: company_id, company_domain: company_domain).limit(1) }

  scope :of_this_week, -> (company_id, company_domain){ where(record_collected_at: { '$gte': Date.today.beginning_of_week, '$lte': Date.today.end_of_week }, company_id: company_id, company_domain: company_domain) }
  scope :of_last_week, -> (company_id, company_domain){ where(record_collected_at: { '$gte': (Date.today.beginning_of_week.yesterday).beginning_of_week, '$lte': (Date.today.beginning_of_week.yesterday).end_of_week }, company_id: company_id, company_domain: company_domain) }
  scope :of_specific_week, -> (company_id, company_domain, date){ where(record_collected_at: { '$gte': date.beginning_of_week, '$lte': date.end_of_week }, company_id: company_id, company_domain: company_domain) }

  scope :fetch_date_and_field_based_statistic, -> (company_id, company_domain, field_value, date, field){ where(record_collected_at: date, company_id: company_id, company_domain: company_domain, "#{field}": field_value).limit(1) }
  scope :fetch_date_and_field_based_statistics, -> (company_id, company_domain, field_value, date, field){ where(record_collected_at: date, company_id: company_id, company_domain: company_domain, "#{field}": field_value) }

  scope :fetch_field_based_statistic, -> (company_id, company_domain, field_value, field){ where(company_id: company_id, company_domain: company_domain, "#{field}": field_value).limit(1) }
  scope :fetch_field_based_statistics, -> (company_id, company_domain, field_value, field){ where(company_id: company_id, company_domain: company_domain, "#{field}": field_value) }

  validates :company_id, :record_collected_at, :company_domain, presence: true

  index({ company_id: 1, company_domain: 1, record_collected_at: -1 })
  index({ record_collected_at: -1 })
end 