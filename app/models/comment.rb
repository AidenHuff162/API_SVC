class Comment < ApplicationRecord
  include CommentManagement
  acts_as_paranoid
  has_paper_trail

  attr_accessor :check_for_mail, :create_activity
  belongs_to :commentable, polymorphic: true
  belongs_to :commenter, class_name: 'User', foreign_key: :commenter_id
  belongs_to :company
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE), allow_nil: true

  before_save :maintain_mentioned_users_uniqueness
  before_save :assign_company_id
  after_commit :check_mail, on: :create
  before_save :add_activity
  after_commit :send_email_to_users, on: :create

  default_scope { order(created_at: :desc) }

  def get_token_replaced_description
    description= self.description
    company = self.company
    return unless description
    while description.include? "USERTOKEN" do
      self.mentioned_users.each do |m|
        string_to_replace = "USERTOKEN[" + m.to_s + "]"
        user = company.users.find_by_id(m)
        description = description.sub string_to_replace, user.display_first_name
      end
    end
    return description
  end

  private
  def assign_company_id
    if self.company_id == nil
      self.company_id = self.commenter.company.id
    end
  end
  def add_activity
    if self.check_for_mail.present? || self.create_activity.present?
      pto = self.commentable.reload
      pto.create_comment_activity(self.commenter_id) if pto.present?
    end
  end
  def check_mail
    if self.check_for_mail.present?
      manager = self.commentable.user.manager
      if manager.present? && self.commentable.pto_policy.manager_approval
        TimeOffMailer.send_request_to_manager_for_approval_denial(self.commentable_id, nil, self.id, manager, { request_time_modified: true, check_for_mail: self.check_for_mail }).deliver_now!
      end
    end
  end

  def maintain_mentioned_users_uniqueness
    mentioned_users = mentioned_users.to_a.uniq
  end

  def send_email_to_users
    if self.commentable_type == "TaskUserConnection"
      Rails.cache.delete([self.commentable_id, 'tuc_comments_count'])
      send_email_to_task_owner(self) unless self.commentable.present? && self.commentable.owner_type == "workspace" && self.commentable.owner_id == self.commentable.user_id
    end
    send_email_to_mentioned_users(self)
  end
end
