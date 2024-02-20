module CustomTableSerializer
  class MinimalData < ActiveModel::Serializer
    attributes :id, :name, :table_type, :is_approval_required
  end
end
