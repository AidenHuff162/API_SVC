module Pto
  class Shared
    def self.object estimated_balance, logs,  carryover_balance = nil
      object={}
      object[:estimated_balance] = estimated_balance
      object[:audit_logs] = logs
      object[:carryover_balance] = carryover_balance if carryover_balance
      object
    end
  end
end
