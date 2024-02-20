class TaskUserConnectionForm < BaseForm
  presents :task_user_connection

  attribute :state, String
  attribute :owner_id, Integer
  attribute :due_date, Date
end
