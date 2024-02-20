class HistoryUser < ApplicationRecord
  has_paper_trail
  belongs_to :history
  belongs_to :user
end
