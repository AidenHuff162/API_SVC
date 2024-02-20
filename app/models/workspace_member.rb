class WorkspaceMember < ApplicationRecord
  belongs_to :member, class_name: 'User', foreign_key: :member_id
  belongs_to :workspace

  validates :workspace_id, uniqueness: { scope: :member_id }, if: -> { member_id.present? && workspace_id.present? }
  # validates_presence_of :workspace_id
  # validates_presence_of :member_id

  enum member_role: { user: 0, admin: 1 }
  before_destroy :switch_notification

  def switch_notification
    if !self.workspace.notification_all && self.workspace.notification_ids.present?
      self.workspace.notification_ids.delete(self.member_id)
      self.workspace.notification_all = true if self.workspace.notification_ids.length == 0
      self.workspace.save!
    end
  end
end
