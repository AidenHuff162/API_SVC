module ProfileTemplateSerializer
  class ProfilePage < ActiveModel::Serializer
    attributes :id, :name
    has_many :profile_template_custom_table_connections, serializer: ProfileTemplateCustomTableConnectionSerializer::ProfilePage
    has_many :profile_template_custom_field_connections, serializer: ProfileTemplateCustomFieldConnectionSerializer::ProfilePage

  end
end
