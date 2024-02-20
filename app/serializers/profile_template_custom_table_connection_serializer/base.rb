module ProfileTemplateCustomTableConnectionSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :position, :custom_table_id, :custom_table

    def custom_table
      if object.custom_table_id
        ActiveModelSerializers::SerializableResource.new(object.custom_table, serializer: CustomTableSerializer::Basic)
      else
        nil
      end
    end

  end
end
