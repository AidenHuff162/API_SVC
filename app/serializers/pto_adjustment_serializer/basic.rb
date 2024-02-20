module PtoAdjustmentSerializer
  class Basic < ActiveModel::Serializer

    attributes :id, :hours, :description, :effective_date, :operation, :created_timestamp, :created_at, :policy_name, :policy_tracking_unit, :policy_id, :working_hours
    belongs_to :creator, serializer: UserSerializer::PtoAdjustmentCreator
    def created_timestamp
      object.created_at.to_i
    end

    def policy_name
      object.assigned_pto_policy.pto_policy.name
    end

    def policy_tracking_unit
      object.assigned_pto_policy.pto_policy.tracking_unit
    end

    def policy_id
      object.assigned_pto_policy.pto_policy.id
    end

    def working_hours
      object.assigned_pto_policy.pto_policy.working_hours
    end
  end
end
