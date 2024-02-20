module ProfileTemplateSerializer
  class BulkOnboarding < ActiveModel::Serializer
    attributes :id, :name, :meta
    has_many :profile_template_custom_table_connections, serializer: ProfileTemplateCustomTableConnectionSerializer::BulkOnboarding
    has_many :profile_template_custom_field_connections, serializer: ProfileTemplateCustomFieldConnectionSerializer::BulkOnboarding

  end
end
