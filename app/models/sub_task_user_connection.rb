class SubTaskUserConnection < ApplicationRecord
  attr_accessor :agent_id
  acts_as_paranoid
  has_paper_trail

  belongs_to :sub_task
  belongs_to :task_user_connection
  after_update :flush_cache, if: Proc.new {|task| task.saved_change_to_state?}
  before_destroy :flush_cache

  validates :sub_task, :task_user_connection, presence: true
  validates :task_user_connection_id, uniqueness: { scope: :sub_task_id }

  state_machine :state, initial: :in_progress do
    event :complete do
      transition in_progress: :completed
    end
  end

  def flush_cache
    self.task_user_connection.expire_sub_task_status rescue true
  end
end
