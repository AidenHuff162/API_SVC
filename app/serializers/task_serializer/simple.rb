module TaskSerializer
  class Simple < ActiveModel::Serializer
    attributes :id, :name, :description, :workstream_id, :owner_id, :deadline_in, :position, :task_type, :created_at,
               :time_line, :before_deadline_in, :custom_field_id, :sanitized_name, :dependent_tasks

    belongs_to :owner, class_name: 'User', serializer: UserSerializer::History
    has_many :attachments, serializer: AttachmentSerializer
    has_many :sub_tasks, serializer: SubTaskSerializer::Base
  end
end
