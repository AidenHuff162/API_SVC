module TaskUserConnectionSerializer
  class ActivityStream < ActiveModel::Serializer
    attributes :id, :due_date, :description, :workstream_id, :type, :created_at
    has_one :user, serializer: UserSerializer::Basic

    def description
      object.task.name
    end

    def workstream_id
      object.task.workstream_id
    end

    def type
      'task'
    end
  end
end
