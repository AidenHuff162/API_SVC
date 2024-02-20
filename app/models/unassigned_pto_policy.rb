class UnassignedPtoPolicy < ApplicationRecord
	acts_as_paranoid
	belongs_to :user
	belongs_to :pto_policy

	validates_presence_of :user_id, :pto_policy_id, :effective_date, :starting_balance
	validates_uniqueness_of :user_id, scope: :pto_policy_id
  validates :starting_balance, numericality: true
end
