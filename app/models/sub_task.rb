class SubTask < ApplicationRecord
  acts_as_paranoid
  has_paper_trail

  belongs_to :task
  has_many :sub_task_user_connections, dependent: :destroy
  has_many :task_user_connections, through: :sub_task_user_connections

  after_create :update_sub_task_user_connections, if: Proc.new { |sub_task| sub_task.task&.task_user_connections.present? }

  validates_presence_of :title
  validates_presence_of :task, :on => :update

  state_machine :state, initial: :in_progress do
    event :complete do
      transition in_progress: :completed
    end
  end

  private

  def update_sub_task_user_connections
    self.task.task_user_connections.each do |task_user_connection|
      task_user_connection.sub_task_user_connections.create!(sub_task_id: self.id, state: self.state)
    end
  end
end
