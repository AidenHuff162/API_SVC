module CustomTableSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :table_type, :custom_table_property, :position, :is_approval_required, :approval_type, :approval_ids, :approval_expiry_time, :approve_by_user, :approval_chains, :used_in_templates_count
    has_many :custom_fields, serializer: CustomFieldSerializer::WithOptions

  	def approve_by_user
  		if object.approval_type == 'person' && object.approval_ids.count == 1
  			user_id = object.approval_ids.first
  			object.company.users.find_by(id: user_id)
  		end
  	end

    def approval_chains
      ActiveModelSerializers::SerializableResource.new(object.approval_chains.order(id: :asc), each_serializer: ApprovalChainSerializer::Basic, company: object.company_id)
    end

    def used_in_templates_count
      ProfileTemplate.joins(:profile_template_custom_table_connections).where(profile_template_custom_table_connections: {custom_table_id: object.id}).count
    end
    
  end
end
