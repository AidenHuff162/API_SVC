class PtoAdjustment < ApplicationRecord
  acts_as_paranoid
  belongs_to :creator, class_name: "User", foreign_key: "creator_id"
  belongs_to :assigned_pto_policy
  after_save :make_adjustment, :if => Proc.new {|a| (a.effective_date <= DateTime.now.utc.in_time_zone(a.creator.company.time_zone).to_date)}
  before_destroy :deduct_hours, :if => Proc.new {|a| (a.deleted_by_user == true)}
  attr_accessor :deleted_by_user
  enum operation: {added: 1, subtracted: 2}

  validates_presence_of :hours, :description, :effective_date, :creator_id, :assigned_pto_policy_id, :operation
  validates_inclusion_of :is_applied, in: [true, false]
  validates_numericality_of :hours
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE), allow_nil: true

  def make_adjustment
    user = self.creator
    if self.effective_date.present? && self.effective_date <= DateTime.now.utc.in_time_zone(user.company.time_zone).to_date
      assigned_pto_policy = self.assigned_pto_policy
      pto_balance_audit_log = initialize_balance_audit_log(assigned_pto_policy, user)
      pto_balance_audit_log = update_policy_and_log_hours(assigned_pto_policy, pto_balance_audit_log)
      pto_balance_audit_log.save!
      self.update_columns(is_applied: true)
    end
  end

  private
  def initialize_balance_audit_log(assigned_pto_policy, user)
    PtoBalanceAuditLog.new(assigned_pto_policy_id: assigned_pto_policy.id,
                            user_id: assigned_pto_policy.user_id,
                            balance_updated_at: self.assigned_pto_policy.pto_policy.company.time.to_date,
                            description: "Manual adjustment made by #{user.preferred_full_name} with effective date of #{self.effective_date}")
  end

  def update_policy_and_log_hours(assigned_pto_policy,pto_balance_audit_log)
    if self.operation == "added"
        assigned_pto_policy.update_columns(balance: (assigned_pto_policy.balance + self.hours))
        pto_balance_audit_log.balance_added = self.hours
    elsif self.operation == "subtracted"
        assigned_pto_policy.update_columns(balance: (assigned_pto_policy.balance - self.hours))
        pto_balance_audit_log.balance_used = self.hours
    end
    pto_balance_audit_log.balance = assigned_pto_policy.balance + assigned_pto_policy.carryover_balance
    pto_balance_audit_log
  end

  def deduct_hours
    log = PtoBalanceAuditLog.new(assigned_pto_policy_id: assigned_pto_policy.id,
                            user_id: assigned_pto_policy.user_id,
                            balance_updated_at: self.assigned_pto_policy.user.company.time.to_date,
                            description: "Deleted Adjustment")
    if self.operation == "subtracted"
      self.assigned_pto_policy.update(balance: self.assigned_pto_policy.balance + self.hours)
      log.balance_added = self.hours
    else
      self.assigned_pto_policy.update(balance: self.assigned_pto_policy.balance - self.hours)
      log.balance_used = self.hours
    end
    log.balance = self.assigned_pto_policy.balance + self.assigned_pto_policy.carryover_balance
    log.save!
  end
end
