class DeletedUserEmail < ApplicationRecord
  include UserStatisticManagement
  
  has_paper_trail

  belongs_to :user
  validates :email, :personal_email, presence: true
end
