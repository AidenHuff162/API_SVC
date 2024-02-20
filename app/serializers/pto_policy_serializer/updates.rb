module PtoPolicySerializer
  class Updates < ActiveModel::Serializer
    attributes :id, :name, :policy_type, :unlimited_policy, :icon, :available_hours, :tracking_unit, :half_day_enabled, :policy_type_value, :working_hours, :carryover_balance
    attribute :custom_unlimited_type_title, if: :is_unlimited_policy?

    def available_hours
      object.available_hours(@instance_options[:object]) 
    end

    def carryover_balance
      AssignedPtoPolicy.where(user_id: @instance_options[:object].id, pto_policy_id: object.id).first&.carryover_balance if object.carry_over_unused_timeoff
    end

    def policy_type_value
      PtoPolicy.policy_types[object.policy_type]
    end

    def is_unlimited_policy?
      object.unlimited_policy
    end

    def custom_unlimited_type_title
      object.get_unlimited_policy_title
    end

  end
end
