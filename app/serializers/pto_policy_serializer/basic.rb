module PtoPolicySerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :policy_type, :unlimited_policy, :icon, :for_all_employees, :available_hours, :tracking_unit, :hours_used, :half_day_enabled, :scheduled_hours, :policy_type_value,
                :working_hours, :display_detail, :carryover_balance
    attribute :is_manually_assigned, if: :policy_is_manually_assigned?
    attribute :show_manaul_assignment_link, if: :manual_assignment_done?
    attribute :custom_unlimited_type_title, if: :is_unlimited_policy?

    def available_hours
      object.available_hours(@instance_options[:object]) 
    end

    def hours_used
    	object.hours_used(@instance_options[:object])
    end

    def carryover_balance
      AssignedPtoPolicy.where(user_id: @instance_options[:object].id, pto_policy_id: object.id).first.carryover_balance if object.carry_over_unused_timeoff
    end

    def scheduled_hours
      object.scheduled_hours(@instance_options[:object])
    end

    def policy_type_value
      PtoPolicy.policy_types[object.policy_type]
    end

    def policy_is_manually_assigned?
      @instance_options[:parent_serlaizer].present? && @instance_options[:parent_serlaizer] == 'home_time_off'
    end

    def is_manually_assigned
      AssignedPtoPolicy.where(user_id: @instance_options[:object].id, pto_policy_id: object.id).first.manually_assigned
    end

    def manual_assignment_done?
      @instance_options[:manually_assigned].present? && @instance_options[:manually_assigned] == true
    end

    def show_manaul_assignment_link
      @instance_options[:object].count_of_policies_not_assigned_to_user > 0
    end

    def is_unlimited_policy?
      object.unlimited_policy
    end

    def custom_unlimited_type_title
      object.get_unlimited_policy_title
    end

  end
end
