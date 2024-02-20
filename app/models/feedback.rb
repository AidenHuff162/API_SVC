class Feedback < ApplicationRecord
  belongs_to :user
  belongs_to :company
  validates_presence_of :module
end
