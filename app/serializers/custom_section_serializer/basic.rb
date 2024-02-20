module CustomSectionSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :section, :is_approval_required, :approval_expiry_time, :approval_chains, :name

    def approval_chains
      ActiveModelSerializers::SerializableResource.new(object.approval_chains.order(id: :asc), each_serializer: ApprovalChainSerializer::Basic, company: object.company_id)
    end
    
    def name
      object.section_name
    end
  end
end
