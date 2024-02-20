module WorkstreamSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :tasks_count, :sort_type

  end
end
