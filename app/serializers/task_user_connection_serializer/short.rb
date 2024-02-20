module TaskUserConnectionSerializer
  class Short < ActiveModel::Serializer
    attributes :id, :user_id, :task_id, :state, :due_date
    belongs_to :user, serializer: UserSerializer::Short

    def due_date
      if object.due_date
        object.due_date
      else
        object.user.start_date + object.task.deadline_in
      end
    end
  end
end
