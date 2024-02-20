module ApprovalChainSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :approval_type, :approval_ids, :approve_by_user,
      :approval_value

    def approve_by_user
      if object.approval_type == 'person' && object.approval_ids.count == 1
        user = User.where(company_id: @instance_options[:company], id: object.approval_ids.first).take
        ActiveModelSerializers::SerializableResource.new(user, serializer: UserSerializer::AlgoliaMock) if user.present?
      end
    end

    def approval_value
      if ['manager', 'requestor_manager', 'coworker'].include?(object.approval_type) && object.approval_ids && object.approval_ids.count == 1
        object.approval_ids.first
      end
    end
    
  end
end
