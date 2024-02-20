module ProfileTemplateCustomTableConnectionSerializer
  class ProfilePage < ActiveModel::Serializer
    attributes :id, :position, :custom_table_id

  end
end
