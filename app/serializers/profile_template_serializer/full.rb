module ProfileTemplateSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :name, :edited_by_id, :meta, :process_type_id, :updated_at, :users_count, :process_type, :edited_by_name, :field_count
    has_many :profile_template_custom_table_connections, serializer: ProfileTemplateCustomTableConnectionSerializer::Base
    has_many :profile_template_custom_field_connections, serializer: ProfileTemplateCustomFieldConnectionSerializer::Base

  end
end
