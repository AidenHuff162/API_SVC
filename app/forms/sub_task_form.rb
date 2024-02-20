class SubTaskForm < BaseForm
  presents :sub_task

  attribute :state, String
  attribute :title, String
  attribute :task_id, Integer
  attribute :position, Integer
end
