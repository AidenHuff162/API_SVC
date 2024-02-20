module IntegrationInventorySerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :api_identifier, :state, :category, :knowledge_base_url, 
      :integration_instances, :logo_url, :display_name, :status

    def integration_instances
      ActiveModelSerializers::SerializableResource.new(IntegrationInstance.by_inventory(object.id, @instance_options[:current_company].id), each_serializer: IntegrationInstanceSerializer::Basic)
    end

	  def logo_url
	  	object.logo_url(@instance_options[:current_company].id)
		end  
  end
end
