class Workspace < ApplicationRecord
  acts_as_paranoid
  belongs_to :company
  belongs_to :workspace_image

  has_many :workspace_members, dependent: :destroy
  has_many :members, through: :workspace_members
  has_many :tasks, dependent: :nullify
  has_many :task_user_connections, dependent: :nullify
  before_update :clear_notification_ids, if: Proc.new { |workspace| workspace.will_save_change_to_notification_all? }
  before_save :downcase_the_associated_email, if: Proc.new { |workspace| workspace.will_save_change_to_associated_email? }

  accepts_nested_attributes_for :workspace_members

  validates :name, presence: true, uniqueness: {case_sensitive: false, scope: :company_id}
  validates :workspace_image_id, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)

  def get_distribution_emails
    emails = []
    if self.notification_all
      emails.push(self.associated_email)
    else
      user_ids = self.workspace_members.where(member_id: self.notification_ids).pluck(:member_id)
      self.company.users.where(id: user_ids).each do |user|
        emails.push(user.email || user.personal_email)
      end
    end

    return emails
  end

  private

  def clear_notification_ids
    self.update_column(:notification_ids, []) if self.notification_all
  end

  def downcase_the_associated_email
    self.associated_email = self.associated_email.downcase if self.associated_email.present?
  end

end
