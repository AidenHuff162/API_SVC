module CustomSectionApprovalSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :custom_section_id, :user_id, :requester_id, :state, :requested_fields, :approval_chain_list, :current_approval_chain, :ctus_approval_chains, :approvers
    
    def requested_fields
      ActiveModelSerializers::SerializableResource.new(object.requested_fields)
    end

    def ctus_approval_chains
      ActiveModelSerializers::SerializableResource.new(object.cs_approval_chains.order(id: :asc), each_serializer: CsApprovalChainSerializer::Basic) if object.state.present?
    end

    def approvers
      object.approvers
    end

    def current_approval_chain
      CsApprovalChain.current_approval_chain(object.id)[0] if object.state.present?
    end

    def approval_chain_list
      object.cs_approval_chain_list(false)
    end
  end
end
