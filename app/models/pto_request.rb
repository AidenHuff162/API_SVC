class PtoRequest < ApplicationRecord
  extend FriendlyId
  include PtoRequestOperations
  include ApprovalChainOperations
  include CalendarEventsCrudOperations
  include Friendlyable, DateManagement
  
  #gems
  has_paper_trail
  friendly_id :hash_id
  acts_as_paranoid

  #relations
  belongs_to :user
  belongs_to :pto_policy, -> { unscope(where: :deleted_at) }
  has_many :activities, as: :activity, dependent: :destroy
  has_one :calendar_event, as: :eventable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy, class_name: 'UploadedFile::Attachment'
  has_many :partner_pto_requests, class_name: 'PtoRequest', foreign_key: :partner_pto_request_id, dependent: :destroy
  belongs_to :pto_request, class_name: 'PtoRequest', foreign_key: :partner_pto_request_id
  has_many :approval_requests, as: :approvable_entity, dependent: :destroy

  attr_accessor :email_flag, :include_comment, :request_auto_updated, :avoid_cancellation_email, :real_end_date,
                :real_end_date_was, :real_balance, :updated_by, :approval_deleted, :skip_email
  
  #validations
  before_validation :set_submission_date, if: Proc.new { |p| p.submission_date.nil? }
  validates_presence_of :begin_date, :end_date, :pto_policy_id, :submission_date
  validates_inclusion_of :partial_day_included, in: [true, false]
  validate :policy_enabled
  validate :is_a_valid_pto_request, if:  Proc.new { |p| !p.email_flag && p.begin_date.present? && p.end_date.present? }
  validate :balance_available, if: Proc.new { |p| (p.status ==  'approved' || p.status == 'pending') && p.begin_date.present? && p.end_date.present? && !p.balance_deducted }
  validate :cannot_deny_approved_cancelled_request
  validate :partial_day_for_multiple_days_request, if: Proc.new { |p| p.partial_day_included }
  validate :maximum_increment_valid?, if: Proc.new { |p| p.pto_policy.has_maximum_increment && p.request_auto_updated.blank? && p.pto_request.blank? }
  validate :minimum_increment_valid?, if: Proc.new { |p| p.pto_policy.has_minimum_increment && p.request_auto_updated.blank? && p.pto_request.blank?}
  validate :partner_request_status_valid?, if: Proc.new { |p| p.pto_request.present? }
  validate :begin_date_greater_than_start_date?
  
  #scopes
  scope :individual_requests, -> { where(partner_pto_request_id: nil) }
  scope :partner_requests, -> { where.not(partner_pto_request_id: nil) }
  scope :persisted, -> { where('id IS NOT NULL')}
  scope :not_cancelled_or_denied, -> { where.not('status IN (?)', [PtoRequest.statuses[:denied], PtoRequest.statuses[:cancelled]])}
  scope :pending_requests, -> { where(status: 'pending')}
  scope :approved_requests, -> { where(status: 'approved') }
  scope :order_by_begin_date, -> { order(:begin_date) }
  scope :pending_and_future_requests, -> (date){ where('status = ? or (DATE(begin_date) > ? and status != ?)', PtoRequest.statuses[:pending], date, PtoRequest.statuses[:denied]) }
  scope :upcoming_requests, -> (date){ where('status < ? and DATE(begin_date) > ?', 2, date) }
  scope :historic_requests, -> (date){ where('(DATE(begin_date) <= ?) or status in (?)', date, [2,3]) }
  scope :overdue_requests, -> { where(status: 'pending', partner_pto_request_id: nil).where('created_at < ?', 5.days.ago) }
  scope :past_requests, -> { where(status: 'pending').where('created_at < ?', 7.days.ago) }
  scope :current_period_future_requests, -> (date, period) {where('status < ? and DATE(begin_date) > ?  and DATE(begin_date) < ?', 2, date, period)  }
  scope :future_requests_next_period, -> (date) {where('status < ? and DATE(begin_date) >= ? ', 2,  date)  }
  scope :current_year_past_requests, -> (date){where('status < ? and DATE(begin_date) <= ?  and DATE(begin_date) >= ?', 2, date, date.beginning_of_year)  }
  scope :approved_requests_in_range, -> (date){where('status = 1 and DATE(begin_date) <= ?  and DATE(end_date) >= ?', date, date)  }
  scope :approved_requests_for_users_with_date_range, -> (start_date, end_date, user_ids){where('status = 1 and DATE(begin_date) >= ?  and DATE(begin_date) <= ? and user_id IN (?)', start_date, end_date, user_ids)  }
  scope :pto_requests_to_be_updated_by_holiday, -> (date, user_ids){where('status < ? and DATE(begin_date) > ? and balance_deducted = ? and user_id IN (?)', 2, date, false, user_ids)  }
  scope :span_based_assigned_ptos, -> (company_id, begin_date, end_date){ joins(:user).where('users.company_id = ? AND DATE(pto_requests.created_at) >= ? AND DATE(pto_requests.created_at) <= ?', company_id, begin_date, end_date) }
  scope :out_of_office_paid_time_off, -> { where('pto_requests.end_date > ? AND pto_requests.begin_date < ?', Date.today - 6.months, Date.today + 6.months).includes(:pto_policy, :user, user: [:location, :team])}


  enum status: { pending: 0, approved: 1, denied: 2, cancelled: 3}

  #callbacks
  before_destroy :check_assigned_policy_on_destroy
  after_create :set_hash_id
  before_update :setPendingStatusOntimeChange, if: Proc.new { |p| (p.will_save_change_to_begin_date? || real_end_date_changed? || p.will_save_change_to_balance_hours?) && p.pto_policy.manager_approval }
  after_save :create_time_off_calendar_event, if: Proc.new {|p|  p.saved_change_to_status? || p.saved_change_to_begin_date? || real_end_date_changed?}
  before_update :add_updated_pto_balance_to_assigned_policy, if: :add_back_balance?
  after_create :update_assigned_policy_balance, if: :update_policy_balance_after_create?
  after_update :update_assigned_policy_balance, if: :update_policy_balance_after_update?
  after_update :add_pto_balance_back_to_assigned_policy, if: :add_back_balance_on_deny_and_cancel?
  after_create :create_approval_requests, if: Proc.new {|p|  p.pto_policy.manager_approval }
  before_update :update_the_approval_requests, if: Proc.new { |p| (p.will_save_change_to_begin_date? || real_end_date_changed? || p.will_save_change_to_balance_hours?) && p.pto_policy.manager_approval }
  before_update :approve_the_current_approval_request, if: Proc.new { |p| (p.will_save_change_to_status?(from: "pending", to: "approved") || p.will_save_change_to_status?(from: "pending", to: "denied")) }
  after_create :send_email_to_respective_role
  after_update :send_email_to_respective_role, if: Proc.new { |p| (p.saved_change_to_status? || p.saved_change_to_begin_date? || real_end_date_changed? || p.saved_change_to_balance_hours?)}
  after_create :send_time_off_custom_alert, if: Proc.new { |p| (p.status == 'pending' && !p.saved_change_to_status? && !avoid_cancellation_email) }
  after_save :send_time_off_custom_alert, if: Proc.new { |p| p.saved_change_to_status? && !avoid_cancellation_email }
  before_destroy :add_pto_balance_back_to_assigned_policy_on_destroy, if: Proc.new { |p| p.assigned_pto_policy.present? && pto_is_of_this_period?}
  after_create :create_pto_created_activity, if: Proc.new { |p| p.pto_request.nil?}
  after_save :send_leave_application_to_xero, if: Proc.new { |p|  p.user.xero_id.present? && p.pto_policy.xero_leave_type_id.present? && p.saved_change_to_status? && p.approved?}
  after_update :update_partner_requests_status, if: Proc.new { |p| (p.status != 'pending' && (p.saved_change_to_status?) && (p.partner_pto_request_id.nil?))}
  accepts_nested_attributes_for :comments, reject_if: :all_blank

  def get_end_date
    return real_end_date if real_end_date.present?
    self.partner_pto_requests.count > 0 ? self.partner_pto_requests.order('id desc').first.end_date : self.end_date
  end

  def get_total_balance
    return real_balance if real_balance.present?
    self.balance_hours + (self.partner_pto_requests.sum(:balance_hours)  rescue 0)
  end

  def get_renewal_date date
    self.pto_policy.accrual_renewal_time == 'anniversary_date' ? self.assigned_pto_policy.anniversary_renewal_date(date) : self.pto_policy.renewal_date(date)
  end

  def get_policy_carryover_expiration_date
    expiry_date = self.pto_policy.carryover_amount_expiry_date
    date = self.begin_date < self.pto_policy.company.time.to_date ? self.pto_policy.company.time.to_date : self.begin_date
    expiry_date.month > date.month || (expiry_date.month == date.month && expiry_date.day > date.day) ? change_year(expiry_date, date.year) : change_year(expiry_date, date.year + 1)
  end

  def send_email_to_respective_role
    return if self.pto_request.present? || self.skip_email

    manager = self.user.manager
    if self.pto_policy.manager_approval
      if ((saved_change_to_balance_hours? && self.balance_hours_before_last_save != 0) || (saved_change_to_begin_date? && self.begin_date_before_last_save != nil) || (real_end_date_changed? && self.end_date_before_last_save != nil))
        self.update_columns(email_options: {"request_time_modified" =>  true, "comment_id" => self.comments.order(id: :desc).first.try(:id), "modifier_id" => User.current.id}) if self.include_comment
        self.update_columns(email_options: {"request_time_modified" =>  true, "comment_id" =>  nil, "modifier_id" => User.current.id}) if !self.include_comment
        send_mail_to_approval_request_users
      elsif self.status == 'pending'
        self.update_columns(email_options: {"comment_id" => self.comments.first.try(:id) }) if self.comments.present?
        send_mail_to_approval_request_users
      elsif status == 'approved' || status == 'denied'
        if self.approval_deleted
          TimeOffMailer.send_email_to_manager_of_auto_approved_request(self.id, User.current, manager).deliver_later!(wait: 3.seconds) if manager.present?
        elsif !request_auto_updated
          TimeOffMailer.send_email_to_nick(self, self.comments.present? ? self.comments.last : nil, self.updated_by.present? ? self.updated_by : User.current).deliver_now!
        elsif request_auto_updated
          TimeOffMailer.send_auto_update_email(self).deliver_now!
        end
      elsif status == 'cancelled' && manager.present? && !avoid_cancellation_email
        TimeOffMailer.send_email_to_manager_on_request_cancel(self, self.comments.present? ? self.comments.first : nil, manager).deliver_now!
      end
    else
      if ((saved_change_to_balance_hours? && self.balance_hours_before_last_save != 0) || (saved_change_to_begin_date? && self.begin_date_before_last_save!= nil) || (real_end_date_changed? && self.end_date_before_last_save != nil)) && manager.present?
        TimeOffMailer.send_email_to_manager_of_auto_approved_request(self.id, User.current, manager, { request_time_modified: true }).deliver_later!(wait: 3.seconds)
      elsif self.status == 'approved' && manager.present?
        TimeOffMailer.send_email_to_manager_of_auto_approved_request(self.id, User.current, manager).deliver_later!(wait: 3.seconds)
      end
    end
  end


  def send_time_off_custom_alert
    return if self.pto_request.present? || self.skip_email

    CustomAlerts::TimeOffCustomAlertJob.set(wait: 3.seconds).perform_later(self.id)
  end

  def calculate_leftover_balance
    pto_policy = self.pto_policy
    return "#{(pto_policy.available_hours(self.user) - pto_policy.scheduled_hours(self.user)).round(2)} hours" if pto_policy.tracking_unit == "hourly_policy"
    return "#{((pto_policy.available_hours(self.user) - pto_policy.scheduled_hours(self.user))/pto_policy.working_hours).round(2)} days" if pto_policy.tracking_unit == "daily_policy"
  end

  def calculate_carryover_balance
    pto_policy = self.pto_policy
    return if self.assigned_pto_policy.nil? || pto_policy.unlimited_policy
    remaining_balance_after_detuction = self.remaining_balance_after_detuction
    available_balance = remaining_balance_after_detuction[:balance]
    carryover_balance = remaining_balance_after_detuction[:carryover_balance]
    leftover = pto_policy.tracking_unit == "hourly_policy" ? "#{available_balance.round(2)} hours" : "#{(available_balance/pto_policy.working_hours).round(2)} days"

    if carryover_balance != 0
      rollover_balance = pto_policy.tracking_unit == 'hourly_policy' ? " (#{ carryover_balance } hours Rollover)" : " (#{(carryover_balance/pto_policy.working_hours).round(2)} days Rollover)"
      leftover = leftover + rollover_balance
    end

    return leftover
  end

  def setPendingStatusOntimeChange
    return if self.pto_request.present?
    if self.status == 'approved'
      self.status = 'pending'
      self.partner_pto_requests.update_all(status: 'pending')
      set_hash_id
    end
    self.update_column(:submission_date, Time.now)
    self.updation_requested = true
  end

  def get_balance_used
    get_balance
  end

  def create_submitted_activity user_id
    description = I18n.t('onboard.home.time_off.activities.submited_request')
    create_activity user_id, description
  end

  def create_auto_approved_activity user_id
    description = I18n.t('onboard.home.time_off.activities.auto_approved_on_create')
    create_activity user_id, description
  end

  def get_request_length
    pto_policy = self.pto_policy
    if self.partial_day_included
      return "#{self.get_total_balance.round(2)} hour(s), partial day" if pto_policy.tracking_unit == "hourly_policy"
      return "#{self.get_total_balance.round(2)/pto_policy.working_hours} day(s), half day" if pto_policy.tracking_unit == "daily_policy"
    else
      return "#{self.get_total_balance.round(2)} hour(s), full day(s)" if pto_policy.tracking_unit == "hourly_policy"
      return "#{self.get_total_balance.round(2)/pto_policy.working_hours} day(s)" if pto_policy.tracking_unit == "daily_policy"
    end
  end

  def create_auto_deny_activity user_id
    description = I18n.t('onboard.home.time_off.activities.auto_approved_on_deny')
    create_activity user_id, description
  end

  def create_comment_activity user_id
    description = I18n.t('onboard.home.time_off.activities.comment_request')
    create_activity user_id, description
  end

  def create_status_related_activity user_id, current_status, previous_status
    if previous_status != current_status && ['approved', 'denied'].include?(current_status)
      description = I18n.t('onboard.home.time_off.activities.approve_or_deny_request', status: current_status)
    elsif current_status == 'cancelled'
      description = I18n.t('onboard.home.time_off.activities.cancelled_request')
    else
      description = I18n.t('onboard.home.time_off.activities.modified_request')
    end

    if description.present?
      create_activity user_id, description
    end
  end

  def update_assigned_policy_balance
    return if self.balance_deducted
    user = self.user
    new_balance = 0
    new_carryover_balance = 0
    unlimited_policy = self.pto_policy.unlimited_policy
    assigned_policy = user.assigned_pto_policies.find_by_pto_policy_id(self.pto_policy_id)
    if assigned_policy
      self.update_column(:balance_deducted, true) if !unlimited_policy
      unless unlimited_policy || self.balance_hours == 0
        balance = self.get_balance_after_deduction(assigned_policy, self.balance_hours)
        self.update_column(:carryover_balance_hours, assigned_policy.carryover_balance - balance[:new_carryover_balance])
        assigned_policy.update(balance: balance[:new_balance], carryover_balance: balance[:new_carryover_balance])
        send_negative_balance_alert(assigned_policy)
        create_audit_log_entry_for_approved_request(assigned_policy, balance[:new_balance] + balance[:new_carryover_balance])
      end
    end
  end

  def get_balance_after_deduction assigned_policy, balance
    if assigned_policy.carryover_balance < 0
      new_balance = assigned_policy.balance - balance
      new_carryover_balance = assigned_policy.carryover_balance
    else
      new_carryover_balance = assigned_policy.carryover_balance - balance
      new_balance = assigned_policy.balance
      if new_carryover_balance < 0
        new_balance = assigned_policy.balance + new_carryover_balance
        new_carryover_balance = 0
      end
    end
    return {new_balance: new_balance, new_carryover_balance: new_carryover_balance}
  end

  def assigned_pto_policy
    assigned_pto_policy ||= self.user.assigned_pto_policies.find_by_pto_policy_id(self.pto_policy_id)
  end

  def amount_to_add_back balance
    return 0 if self.assigned_pto_policy.total_balance >= (self.pto_policy.max_accrual_amount * self.pto_policy.working_hours)
    balance_to_add_back = self.assigned_pto_policy.total_balance + balance > (self.pto_policy.max_accrual_amount * self.pto_policy.working_hours)  ? (self.pto_policy.max_accrual_amount * self.pto_policy.working_hours) - self.assigned_pto_policy.total_balance :  balance
  end

  def add_pto_balance_back_to_assigned_policy
    return if !self.balance_deducted
    if !self.pto_policy.has_max_accrual_amount
      add_pto_balance_to_assigned_policy(self.balance_hours)
    else
      add_pto_balance_to_assigned_policy(amount_to_add_back(self.balance_hours))
    end
  end

  def update_pto_event_type
    type = ('time_off_' + self.pto_policy.policy_type)
    unless self.pto_policy.display_detail
      type = ('unavailable')
    end
    self.calendar_event.update_columns(event_type: CalendarEvent.event_types[type], color: CalendarEvent.event_types[type]) if self.calendar_event
  end

  def pto_not_valid
    !self.assigned_pto_policy.present? || !self.user.present?
  end

  def send_mail_to_approval_request_users
    return if !self.pending? || !self.pto_policy.manager_approval
    approval_request = ApprovalRequest.current_approval_request(self.id)[0]
    if approval_request.present?
      user_approvers = approvers
      if user_approvers['approver_ids'].compact.count == 0
        approval_request.update(request_state: "approved")
        send_mail_to_approval_request_users
      else
        action_performer = self.user
        user_approvers['approver_ids'].try(:each) do |approver_id|
          if self.email_options.nil? || self.email_options['request_time_modified'].nil?
            TimeOff::SendRequestOnSlack.perform_in(10.seconds, self.id, approver_id)
            TimeOffMailer.send_request_to_manager_for_approval_denial(self.id, action_performer.present? ? action_performer : User.current,
              self.email_options.present? ? self.email_options["comment_id"] : nil, User.find(approver_id)).deliver_later!(wait: 3.seconds)
          else
            TimeOffMailer.send_request_to_manager_for_approval_denial(self.id, User.find_by(id: self.email_options["modifier_id"]), 
              self.email_options["comment_id"], User.find(approver_id), { request_time_modified: true }).deliver_later!(wait: 3.seconds)
          end
        end
      end
    end
  end

  def update_partner_requests_status
    status_date = self.user.company.time.to_date
    self.partner_pto_requests.each { |p| p.update!(status: self.status, approval_denial_date: status_date, status_changed_by: self.status_changed_by) }
  end

  def remaining_balance
    amount = get_the_amount_to_add_back if self.id.present? && add_back_balance?
    return Pto::CheckBalanceAvailability.new.remaining_balance(self, self.balance_hours, amount)
  end

  def remaining_balance_after_detuction
    return Pto::CheckBalanceAvailability.new.remaining_balance_after_detuction(self)
  end

  def calculate_begin_date
    return self.partner_pto_requests.max_by { |d| d.begin_date }.begin_date
  end

  def self.pending_pto_request type, current_company, user_id
    return current_company.users.find(user_id).pto_requests.joins({pto_policy: :approval_chains}).where(pto_requests: {status: "pending"}, approval_chains: {approval_type: type}) if user_id.present? && type.present? && current_company.present?
  end

  def get_date_range
    TimeConversionService.new(user.company).format_pto_dates(begin_date, get_end_date)
  end

  def get_return_day(is_digest)
    Pto::GetReturnDayOfUser.new.perform(self, is_digest)
  end

  private
  def send_negative_balance_alert assigned_policy
    if balance_got_negative(assigned_policy) && (self.begin_date_before_last_save.nil? || !add_back_balance? || (self.saved_change_to_balance_hours? && self.balance_hours > self.balance_hours_before_last_save))
      CustomAlerts::TimeOffCustomAlertJob.set(wait: 3.seconds).perform_later(self.id, true)
    end
  end

  def balance_got_negative assigned_policy
    assigned_pto_policy.total_balance < 0 && assigned_policy.pto_policy.can_obtain_negative_balance
  end

  def maximum_increment_valid?
    self.errors.add(:base, "Request's balance hours are greater than maximum increment") if self.get_total_balance > self.pto_policy.maximum_increment_amount 
  end

  def minimum_increment_valid?
    self.errors.add(:base, "Request's balance hours are less than minimum increment") if self.get_total_balance < self.pto_policy.minimum_increment_amount 
  end

  def add_back_balance?
    !self.pto_policy.unlimited_policy && (partial_hours_changed_before || (self.will_save_change_to_begin_date? || self.will_save_change_to_end_date?)) && (self.status == "approved" || self.status == "pending") && self.begin_date_in_database.to_date <= self.pto_policy.company.time.to_date && self.begin_date_in_database >= (self.get_renewal_date(self.pto_policy.company.time.to_date) - 1.year)
  end

  def update_policy_balance_after_create?
    (self.status == "approved" || self.status == "pending") && pto_is_of_this_period?
  end

  def update_policy_balance_after_update?
    (partial_hours_changed_after || self.saved_change_to_begin_date? || self.saved_change_to_end_date?) && (self.status == "approved" || self.status == "pending") && pto_is_of_this_period?
  end

  def add_back_balance_on_deny_and_cancel?
    !self.pto_policy.unlimited_policy && (self.status_before_last_save == "approved" || self.status_before_last_save == "pending") && (self.status == "cancelled" || self.status == "denied") && (pto_is_of_this_period? || (pto_is_of_last_period? && can_add_back_carryover?))
  end

  def pto_is_of_last_period?
    company_date = self.pto_policy.company.time.to_date
    begin_date = self.begin_date
    begin_date <= company_date && begin_date >= (self.get_renewal_date(company_date) - 2.year) && begin_date <= (self.get_renewal_date(company_date) - 1.year)
  end

  def can_add_back_carryover?
    self.assigned_pto_policy.initial_carryover_balance.present? && ( !self.pto_policy.has_maximum_carry_over_amount || self.assigned_pto_policy.initial_carryover_balance < self.pto_policy.max_carryover_balance_hours)
  end

  def pto_is_of_this_period?
    self.begin_date.to_date <= self.pto_policy.company.time.to_date && self.begin_date >= (self.get_renewal_date(self.pto_policy.company.time.to_date) - 1.year)
  end

  def create_audit_log_entry_for_approved_request assigned_policy, new_balance
    description = self.begin_date == self.end_date ? "Used (#{log_format(self.begin_date)})" :  "Used(#{log_format(self.begin_date)} to #{log_format(self.end_date)})"
    assigned_policy.pto_balance_audit_logs.create(balance_updated_at: self.user.company.time.to_date, description: description, balance_used: self.balance_hours,
                                                  user_id: assigned_policy.user_id, balance: new_balance)
  end

  def create_audit_log_entry_adding_back_balance assigned_policy, balance
    description = self.begin_date_in_database == self.end_date_in_database ? "Added Back(#{log_format(self.begin_date_in_database)})" :  "Added Back(#{log_format(self.begin_date_in_database)} to #{log_format(self.end_date_in_database)})"
    assigned_policy.pto_balance_audit_logs.create(balance_updated_at: self.user.company.time.to_date, description: description, balance_added: balance,
                                                  user_id: assigned_policy.user_id, balance: (assigned_policy.balance + assigned_pto_policy.carryover_balance))
  end

  def create_activity user_id, description
    self.activities.create(agent_id: user_id, description: description)
  end

  def create_time_off_calendar_event
    return if self.pto_request.present?
    company = self.user.company
    if company.enabled_calendar
      self.calendar_event.really_destroy! if self.calendar_event.present?
      if self.status == 'approved'
        pto_policy = 'time_off_' + self.pto_policy.policy_type
        setup_calendar_event(self, pto_policy, company, self.begin_date, self.get_end_date)
      end
    end
  end

  def is_a_valid_pto_request
    user = self.user
    existing_pto_request = user.pto_requests.persisted.not_cancelled_or_denied
    if is_endtime_greaterthan_begintime?
      if existing_pto_request.present?
        if check_if_pto_requests_overlaps_existing_pto_requests(existing_pto_request)
          self.errors.add('A', I18n.t('errors.pto_overlapping').to_s)
        end
      end
    else
      self.errors.add(:PtoRequest, I18n.t('errors.pto_end_date_greater_than_begin_date').to_s)
    end
  end

  def check_if_pto_requests_overlaps_existing_pto_requests existing_pto_requests
    is_overlapping = nil
    overlapping_requests = []
    existing_pto_requests.each do |request|
      if is_an_overlapping_request(self, request) and request.id != self.id
        is_overlapping = self.partial_day_included && request.partial_day_included ? false : true
        overlapping_requests << request unless is_overlapping
      end
    end
    balance_is_less_than_working_hours(overlapping_requests) if is_overlapping ==  false
    is_overlapping
  end

  def balance_is_less_than_working_hours overlapping_requests
    total_balance = self.balance_hours + overlapping_requests.pluck(:balance_hours).sum
    working_hours = ([self.pto_policy.working_hours] + overlapping_requests.map { |req| req.pto_policy.working_hours }.compact).max
    self.errors.add('You ', I18n.t('errors.invalid_pto_balance').to_s) if total_balance > working_hours
  end

  def is_an_overlapping_request new_request, existing_request
    (new_request.begin_date..new_request.end_date).overlaps? (existing_request.begin_date..existing_request.end_date)
  end

  def is_endtime_greaterthan_begintime?
    self.begin_date.present? && self.end_date.present? && self.begin_date <= self.end_date
  end

  def balance_available
    return if self.changes_to_save == {} || (self.saved_change_to_status?(from: "pending", to: "approved")  && self.pto_policy.manager_approval)
    amount = get_the_amount_to_add_back if self.id.present? && add_back_balance?
    if !Pto::CheckBalanceAvailability.new.perform(self, self.balance_hours, amount)
      self.errors.add(:policy, I18n.t('errors.out_of_balance').to_s)  if !self.pto_policy.can_obtain_negative_balance
      self.errors.add(:base, I18n.t('errors.out_of_negative_balance').to_s)  if self.pto_policy.can_obtain_negative_balance
    end
  end

  def cannot_deny_approved_cancelled_request
    if self.changes_to_save["status"].present? and (self.changes_to_save["status"].first == 'approved' || self.changes_to_save["status"].first == 'cancelled') and self.changes_to_save["status"].last == "denied"
      self.errors.add(" ", I18n.t('errors.cannot_deny').to_s)
    elsif self.changes_to_save["status"].present? and (self.changes_to_save["status"].first == 'denied' || self.changes_to_save["status"].first == 'cancelled') and self.changes_to_save["status"].last == "approved"
      self.errors.add(" ", I18n.t('errors.cannot_approve').to_s)
    end
  end

  def get_the_amount_to_add_back
    if !self.pto_policy.has_max_accrual_amount
      return self.balance_hours_in_database
    else
      if !update_policy_balance_after_update?
        return amount_to_add_back(self.balance_hours_in_database)
      else
        if self.balance_hours_in_database <= self.balance_hours
          return self.balance_hours_in_database
        else
          return amount_to_add_back(self.balance_hours_in_database - self.balance_hours) + self.balance_hours
        end
      end
    end
  end

  def add_updated_pto_balance_to_assigned_policy
    add_pto_balance_to_assigned_policy(get_the_amount_to_add_back)
  end

  def add_pto_balance_to_assigned_policy balance
    self.update_column(:balance_deducted, false)
    if pto_is_of_last_period? && can_add_back_carryover?
      balance = get_carryover_balance(balance) if self.pto_policy.has_maximum_carry_over_amount
      self.carryover_balance_hours = balance
      self.assigned_pto_policy.initial_carryover_balance += balance
    end
    if balance != 0
      self.assigned_pto_policy.update_columns(carryover_balance: (self.assigned_pto_policy.carryover_balance + self.carryover_balance_hours ), balance: (self.assigned_pto_policy.balance + (balance - self.carryover_balance_hours)), initial_carryover_balance: self.assigned_pto_policy.initial_carryover_balance)
      self.update_column(:carryover_balance_hours, 0.0)
      create_audit_log_entry_adding_back_balance self.assigned_pto_policy, balance
    end
  end

  def get_carryover_balance balance
    initial_carryover_balance = self.assigned_pto_policy.initial_carryover_balance
    max_carryover_balance_hours = self.pto_policy.max_carryover_balance_hours
    initial_carryover_balance + balance > max_carryover_balance_hours ? max_carryover_balance_hours - initial_carryover_balance : balance
  end

  def partial_day_for_multiple_days_request
    pto_policy = self.pto_policy
    if pto_policy.tracking_unit == "daily_policy"
      self.errors.add(" ", I18n.t('errors.half_day_error').to_s) if !pto_policy.half_day_enabled || (self.begin_date != self.end_date)
    else
      self.errors.add(" ", I18n.t('errors.partial_day_error').to_s) if (self.begin_date != self.end_date)
    end
  end

  def policy_enabled
    if !self.pto_policy.is_enabled
      self.errors.add(:policy, I18n.t('errors.policy_disabled').to_s)
    end
  end

  def add_pto_balance_back_to_assigned_policy_on_destroy
    add_pto_balance_back_to_assigned_policy
  end

  def real_end_date_changed?
    real_end_date && real_end_date_was && real_end_date != real_end_date_was
  end

  def log_format date
    date.strftime("%d/%m/%Y")
  end

  def partial_hours_changed_before
    self.partial_day_included? && self.will_save_change_to_balance_hours?
  end

  def partial_hours_changed_after
    self.partial_day_included? && self.saved_change_to_balance_hours?
  end

  def create_approval_requests
    return if self.pto_request.present?
    self.pto_policy.approval_chains.order(id: :asc).try(:each) do |approval_chain|
      next if approval_chain.approval_type == "manager" && self.user.manager.nil?
      self.approval_requests.create(approval_chain_id: approval_chain.id, request_state: 'requested')
    end
  end


  def update_the_approval_requests
    return if self.pto_request.present?
    self.approval_requests.destroy_all
    create_approval_requests
    set_hash_id
  end

  def approve_the_current_approval_request
    return if self.request_auto_updated || self.pto_request.present?
    approval_request = ApprovalRequest.current_approval_request(self.id)[0]
    approval_request.update(request_state: self.status) if approval_request
    set_hash_id
    send_next_approval_email if self.status == "approved" && !self.skip_email
    self.approval_requests.where(request_state: ApprovalRequest.request_states[:requested]).destroy_all if self.status == "denied"
  end

  def send_next_approval_email
    if (ApprovalRequest.current_approval_request(self.id)).count > 0
      approver_ids = approvers['approver_ids'].compact
      if approver_ids.count == 1 && approver_ids.first == User.current.id
        approve_the_current_approval_request
      else
        self.status = "pending"
        send_mail_to_approval_request_users
      end
    end
  end

  def create_pto_created_activity
    PtoRequestService::Activity::CreateActivity.new(self, User.current.id, 'CREATED_REQUEST').perform
  end

  def set_submission_date
    self.submission_date = Time.now
  end
  
  def send_leave_application_to_xero
    return if self.pto_request.present? || !self.user.company.is_xero_integrated?

    ::HrisIntegrations::Xero::CreateLeaveApplicationInXero.perform_in(10.seconds, self.id)
  end

  def partner_request_status_valid?
    if self.pto_request.status != self.status
      self.errors.add(' ', I18n.t('errors.invalid_status').to_s)
    end
  end
  
  def begin_date_greater_than_start_date?
    if self.begin_date.present? && self.begin_date < self.user.start_date
      self.errors.add(" ", I18n.t('errors.start_date_error').to_s)
    end
  end

  def check_assigned_policy_on_destroy
    return true if self.partner_pto_request_id.present? || self.assigned_pto_policy == nil
    self.errors.add(" ", I18n.t('errors.cannot_destroy_pto').to_s)
    throw(:abort)
  end
end
