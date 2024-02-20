class AssignedPtoPolicy < ApplicationRecord
  include UserStatisticManagement, DateManagement
  
  acts_as_paranoid
  attr_accessor :skip_before_destroy_callback
  belongs_to :user
  belongs_to :pto_policy
  has_many :pto_balance_audit_logs, dependent: :destroy
  has_many :pto_adjustments, dependent: :destroy

  validates_presence_of :pto_policy_id, :user_id
  validates_uniqueness_of :pto_policy_id, scope: :user_id

  after_create :add_audit_log
  after_create :add_manually_assigned_balance_log, if: Proc.new { |p| p.manually_assigned }
  after_create :initialize_accrual_start_date_and_happening_date, if: :is_limited_policy?
  after_update :set_initial_balance_of_assigned_policy, if: :is_acrual_happening_today?
  after_restore :set_accrual_dates, if: Proc.new { |p| p.pto_policy&.unlimited_policy == false && p.user&.start_date.present?  }
  after_restore :remove_duplicated_policies
  after_restore { reset_balance_and_create_logs(true) }
  before_destroy  :reset_balance_and_create_logs 

  scope :eagerload_users_and_requests, ->  { includes(user: :pto_requests) }
  scope :auto_assigned_policies, -> { where(manually_assigned: false)}

  def set_accrual_start_date date=nil
    policy = self.pto_policy
    date ||= self.created_at.in_time_zone(self.pto_policy.company.time_zone).to_date
    return if policy.blank?
    start_date = policy.start_of_accrual_period == 'custom_start_date' ? self.user.start_date + policy.accrual_period_start_date : self.user.start_date
    if policy.allocate_accruals_at == "start" && policy.accrual_frequency != 'annual'
      start_date = date > start_date ? Pto::AccrualHappeningDate.new(self.pto_policy, date).get_start_date : start_date
    else
      start_date = date > start_date ? date : start_date
    end
    self.update(start_of_accrual_period: start_date)
  end

  def set_first_accrual_happening_date
    self.update(first_accrual_happening_date: Pto::AccrualHappeningDate.new(self.pto_policy, self.start_of_accrual_period).perform) if self.pto_policy.present?
  end

  def pto_requests
    PtoRequest.where(user_id: self.user_id, pto_policy_id: self.pto_policy_id)
  end

  def initialize_accrual_start_date_and_happening_date
    set_accrual_start_date
    set_first_accrual_happening_date
  end

  def set_initial_balance_of_assigned_policy
    Pto::ManagePtoBalances.new(0, self.pto_policy.company, true).calculate_initial_balances([self])
  end

  def anniversary_renewal_date date
    user = self.user
    user.start_date.month >  date.month || (user.start_date.month == date.month && user.start_date.day > date.day) ? change_year(user.start_date, date.year) : change_year(user.start_date, (date.year + 1))
  end

  def total_balance
    self.balance + self.carryover_balance
  end

  def reset_policy date
    reset_balance_and_create_logs(true)
    self.update_columns(is_balance_calculated_before: false, first_accrual_happening_date: nil, start_of_accrual_period: nil, balance_updated_at: nil)
    set_accrual_start_date(date)
    set_first_accrual_happening_date
  end

  private

  def remove_duplicated_policies
    latest_assigned_policy = AssignedPtoPolicy.where(pto_policy_id: self.pto_policy_id, user_id: self.user_id).order('id desc').first
    AssignedPtoPolicy.where(pto_policy_id: self.pto_policy_id, user_id: self.user_id).where.not(id: latest_assigned_policy.id).destroy_all
    latest_assigned_policy.destroy  if latest_assigned_policy.pto_policy.blank? || (!self.manually_assigned && !PTO::SharedMethods::UserPolicyFilterMatcher.assigned_policys_user_has_pto_policy_filter?(latest_assigned_policy.pto_policy, latest_assigned_policy))
  end

  def is_acrual_happening_today?
    self.is_balance_calculated_before == false && self.saved_change_to_first_accrual_happening_date? && self.first_accrual_happening_date == DateTime.now.in_time_zone(self.pto_policy.company.time_zone).to_date
  end
  def is_limited_policy?
    self.pto_policy.unlimited_policy == false
  end

  def add_audit_log
    self.pto_balance_audit_logs.create(balance_used: 0, balance_added: 0,  balance: 0, description: "Enrolled in the Policy #{self.pto_policy.name}", balance_updated_at: compnay_date, user_id: self.user_id)
  end

  def add_manually_assigned_balance_log
    self.pto_balance_audit_logs.create(balance_used: 0, balance_added: self.balance,  balance: self.balance, description: "Accrual on Manual Assignment", balance_updated_at: self.user.company.time.to_date, user_id: self.user_id) if self.balance != 0
  end
  
  def reset_balance_and_create_logs(policy_assigned = false)
    unless self.skip_before_destroy_callback.present?
      return if !self.pto_policy || (self.deleted_at.present? && !policy_assigned)
      log_balance = self.balance + self.carryover_balance
      self.update_columns(balance: 0, carryover_balance: 0)
      self.pto_adjustments.destroy_all
      create_log(log_balance) if policy_assigned
      if !policy_assigned
        self.update_column(:is_balance_calculated_before, true)
        create_deleted_log(log_balance)
      end 
    end
  end

  def create_log log_balance
    if log_balance.positive?
      self.pto_balance_audit_logs.create(balance_used: log_balance, balance_added: 0,  balance: 0, description: "Reassigned Policy #{self.pto_policy.name}.", balance_updated_at: compnay_date, user_id: self.user_id)
    else
      self.pto_balance_audit_logs.create(balance_used: 0, balance_added: log_balance.abs,  balance: 0, description: "Reassigned Policy #{self.pto_policy.name}", balance_updated_at: compnay_date, user_id: self.user_id)
    end
  end

  def create_deleted_log log_balance
    if log_balance.positive?
      self.pto_balance_audit_logs.create(balance_used: log_balance, balance_added: 0,  balance: 0, description: "Unassigned Policy #{self.pto_policy.name}.", balance_updated_at: compnay_date, user_id: self.user_id, deleted_at: Time.now)
    else
      self.pto_balance_audit_logs.create(balance_used: 0, balance_added: log_balance.abs,  balance: 0, description: "Unassigned Policy #{self.pto_policy.name}", balance_updated_at: compnay_date, user_id: self.user_id, deleted_at: Time.now)
    end
  end

  def compnay_date
    self.user.company.time.to_date rescue Date.today
  end

  def set_accrual_dates
    self.set_accrual_start_date if self.start_of_accrual_period.nil?
    if self.first_accrual_happening_date.nil?
      self.set_first_accrual_happening_date 
      self.update_column(:is_balance_calculated_before, true) if self.first_accrual_happening_date < self.user.company.time.to_date
    end
  end
end
