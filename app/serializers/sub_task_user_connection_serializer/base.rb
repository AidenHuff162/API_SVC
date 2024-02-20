module SubTaskUserConnectionSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :state, :title, :position

    def title
      object.sub_task.title
    end

    def position
      object.sub_task.position
    end
  end
end
