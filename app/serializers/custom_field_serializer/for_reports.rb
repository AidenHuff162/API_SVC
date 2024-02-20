module CustomFieldSerializer
  class ForReports < ActiveModel::Serializer
    attributes :id, :name, :field_type, :position, :custom_table_id, :custom_field_options, :sub_custom_fields
    has_many :sub_custom_fields, serializer: SubCustomFieldSerializer::Basic

    def sub_custom_fields
    	object.sub_custom_fields.count > 0 ? object.sub_custom_fields : nil
    end

    def custom_field_options
    	object.active_custom_field_options.count > 0 ? object.active_custom_field_options : nil
    end
  end
end
