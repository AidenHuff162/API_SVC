module CustomTableUserSnapshotSerializer
  class ForInfo < ActiveModel::Serializer
    attributes :id, :updated_by, :custom_snapshots, :updated_at, :created_at, :effective_date,
    :state, :request_state, :is_terminated, :terminated_data, :integration_type, 
    :ctus_approval_chains, :current_approval_chain, :approvers, :is_applicable, 
    :is_offboarded, :approval_chain_list

    def updated_by
      object.edited_by.try(:display_name)
    end

    def approvers
      object.approvers
    end

    def custom_snapshots
      company = object.user.company
      custom_snapshots = (company.working_patterns_feature_flag && company.enabled_time_off) ? object.custom_snapshots : object.custom_snapshots.where("preference_field_id != ? OR preference_field_id IS NULL", "wp")

      ActiveModelSerializers::SerializableResource.new(custom_snapshots.includes(:custom_field), each_serializer: CustomSnapshotSerializer::ForInfo, company: @instance_options[:company])
    end

    def ctus_approval_chains
      ActiveModelSerializers::SerializableResource.new(object.ctus_approval_chains.order(id: :asc), each_serializer: CtusApprovalChainSerializer::Basic) if object.request_state.present?
    end

    def current_approval_chain
      CtusApprovalChain.current_approval_chain(object.id)[0] if object.request_state.present?
    end

    def is_offboarded
      object.terminated_data.present? && object.user.departed?
    end

    def approval_chain_list
      object.approval_chain_list(false)
    end
  end
end
