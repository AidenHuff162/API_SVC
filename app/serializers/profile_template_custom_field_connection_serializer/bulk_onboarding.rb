module ProfileTemplateCustomFieldConnectionSerializer
  class BulkOnboarding < ActiveModel::Serializer
    attributes :id, :required, :position, :custom_field_id, :default_field_id

  end
end
