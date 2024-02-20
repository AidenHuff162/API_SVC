module TaskUserConnectionSerializer
  class Light < ActiveModel::Serializer
    attributes :id, :name, :owner, :user, :task_type, :owner_id
    belongs_to :user, serializer: UserSerializer::Basic
    belongs_to :owner, serializer: UserSerializer::Basic

    def task_type
      object.task.task_type
    end

    def name
      Nokogiri::HTML(object.get_task_name).xpath("//*[p]").first.content rescue " "
    end
  end
end
