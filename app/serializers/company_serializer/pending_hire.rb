module CompanySerializer
  class PendingHire < ActiveModel::Serializer
    attributes :id, :name, :bulk_onboarding_feature_flag, :pending_hire_flatfile_access_flag, :smart_assignment_2_feature_flag, :smart_assignment_configuration
  
    def smart_assignment_configuration
      ActiveModelSerializers::SerializableResource.new(object.smart_assignment_configuration, serializer: SmartAssignmentConfigurationSerializer::Basic) if object&.smart_assignment_configuration
    end
  end
end
