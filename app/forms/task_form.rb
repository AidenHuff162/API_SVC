class TaskForm < BaseForm
  presents :task

  PLURAL_RELATIONS = %i(task_user_connections sub_tasks)

  attribute :task_user_connections, Array[TaskUserConnectionForm]
  attribute :position, Integer
  attribute :owner_id, Integer
  attribute :workspace_id, Integer
  attribute :workstream_id, Integer
  attribute :survey_id, Integer
  attribute :sub_tasks, Array[SubTaskForm]
end
