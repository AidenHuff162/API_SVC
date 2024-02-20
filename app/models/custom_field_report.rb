class CustomFieldReport < ApplicationRecord
  has_paper_trail
  belongs_to :report
  belongs_to :custom_field
end
