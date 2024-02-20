class PtoBalanceAuditLog < ApplicationRecord
  acts_as_paranoid
  belongs_to :assigned_pto_policy
  belongs_to :user
  validates_presence_of :balance_updated_at, :balance_added, :assigned_pto_policy_id, :user_id
end
