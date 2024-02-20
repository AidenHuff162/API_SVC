module PtoBalanceAuditLogSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :description, :balance_updated_at, :balance_used, :balance_added, :balance, :tracking_unit, :working_hours
    
    def tracking_unit
      object.assigned_pto_policy.pto_policy.tracking_unit
    end
      
    def working_hours
      object.assigned_pto_policy.pto_policy.working_hours
    end
  end
end
