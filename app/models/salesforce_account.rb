class SalesforceAccount < ApplicationRecord
  belongs_to :company

  validates_uniqueness_of :company_id, if: -> { company_id.present? }
end