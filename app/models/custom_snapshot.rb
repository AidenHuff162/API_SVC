class CustomSnapshot < ApplicationRecord
  has_paper_trail
  belongs_to :custom_field
  belongs_to :custom_table_user_snapshot

  validates :custom_field_value, presence: true, if: proc { |snapshot| snapshot.preference_field_id == 'st' }
end
