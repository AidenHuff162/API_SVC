module PtoRequestSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :begin_date, :end_date, :policy_name, :status, :pto_policy_id, :partial_day_included, :additional_notes,
               :user_full_name, :user_image, :approval_denial_date, :activities, :user_id, :user_initials,
               :balance_hours, :policy_enabled, :created_timestamp, :policy_tracking_unit, :is_past, :working_hours, :policy_available_hours,
               :policy_hours_used, :policy_scheduled_hours, :approvers, :is_manager_approval_remaining, :user_display_name, :return_date, :carryover_balance

    def end_date
      object.get_end_date
    end

    def policy_name
      object.pto_policy.name
    end

    def user_full_name
      object.user.display_name
    end

    def user_display_name
      object.user.company.global_display_name(object.user, object.user.company.display_name_format)
    end

    def user_image
      object.user.picture
    end

    def user_initials
      "#{object.user.preferred_full_name[0,1] } #{object.user.last_name[0,1]}"
    end

    def activities
      pto_activities = object.activities.order('created_at DESC')
      ActiveModelSerializers::SerializableResource.new(pto_activities, each_serializer: ActivitySerializer::Full, company: object.user.company) if pto_activities.present?
    end

    def policy_enabled
      object.pto_policy.is_enabled
    end

    def created_timestamp
      object.created_at.to_i
    end

    def policy_tracking_unit
      object.pto_policy.tracking_unit
    end

    def is_past
      object.user.pto_requests.historic_requests(object.pto_policy.company.time.to_date).pluck(:id).include? object.id
    end

    def working_hours
      object.pto_policy.working_hours
    end

    def policy_available_hours
      object.pto_policy.available_hours(object.user) if get_balances
    end

    def policy_hours_used
      object.pto_policy.hours_used(object.user) if get_balances
    end

    def policy_scheduled_hours
      object.pto_policy.scheduled_hours(object.user) if get_balances
    end

    def get_balances
      scope.present? && scope[:get_balances]
    end

    def balance_hours
      object.get_total_balance
    end

    def carryover_balance
      object.assigned_pto_policy&.carryover_balance
    end

    def approvers
      object.pto_policy.manager_approval && ApprovalRequest.current_approval_request(object.id)[0].present? ? object.approvers["approver_ids"].compact : nil
    end

    def is_manager_approval_remaining
      object.pto_policy.manager_approval ? object.approval_requests.joins(:approval_chain).where(approval_chains: {approval_type: ApprovalChain.approval_types[:manager]},
       request_state: ApprovalRequest.request_states[:requested]).count > 0 : false
    end

    def return_date
      object.get_return_day(false)
    end
    
  end
end
