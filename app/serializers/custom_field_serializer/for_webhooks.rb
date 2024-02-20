module CustomFieldSerializer
  class ForWebhooks < ActiveModel::Serializer
    attributes :id, :section, :name, :api_field_id, :custom_table_id
  end
end
