class EstimatedBalanceSerializer < ActiveModel::Serializer
  type :assigned_pto_policy

  attributes :estimated_balance, :audit_logs, :carryover_balance

  def estimated_balance
    object[:estimated_balance]
  end

  def audit_logs
    object[:audit_logs]
  end

  def carryover_balance
    object[:carryover_balance]
  end
end
