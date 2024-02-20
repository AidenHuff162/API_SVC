module SubTaskSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :title, :task_id, :state, :position
  end
end
