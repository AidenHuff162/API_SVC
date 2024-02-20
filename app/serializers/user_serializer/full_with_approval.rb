module UserSerializer
  class FullWithApproval < Full
    attributes :fields
    has_many :custom_section_approvals, serializer: CustomSectionApprovalSerializer::Basic
    
    def custom_section_approvals
      object.custom_section_approvals.where(state: 'requested', custom_section_id: instance_options[:custom_section_id])
    end

    def fields
      instance_options[:data]
    end
  end
end
