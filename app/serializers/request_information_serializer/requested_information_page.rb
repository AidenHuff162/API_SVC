module RequestInformationSerializer
  class RequestedInformationPage < ActiveModel::Serializer
    attributes :id, :requester_name, :custom_fields, :preference_fields, :profile_field_ids
    has_one :requester, serializer: UserSerializer::Simple

    def requester_name
      object.requester.try(:display_name)
    end

    def custom_fields
      results = CustomFieldsCollection.new({company_id: object.company_id, id: object.profile_field_ids}).results
      if results
        ActiveModelSerializers::SerializableResource.new(results, each_serializer: CustomFieldSerializer::RequestedInformationPage, user_id: object.requested_to_id)
      end
    end

    def preference_fields
      object.company.prefrences['default_fields'].select { |default_field| object.profile_field_ids.include? default_field['id'] }
    end
  end
end
