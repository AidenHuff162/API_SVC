class PtoPolicy < ApplicationRecord
  has_paper_trail
  acts_as_paranoid
  include DateManagement
  belongs_to :company
  belongs_to :editor, class_name: 'User', foreign_key: :updated_by_id
  has_many :assigned_pto_policies, dependent: :destroy
  has_many :unassigned_pto_policies, dependent: :destroy
  has_many :users, through: :assigned_pto_policies
  has_many :pto_requests, dependent: :destroy
  has_many :policy_tenureships, dependent: :destroy
  has_many :approval_chains, as: :approvable, dependent: :destroy
  
  accepts_nested_attributes_for :approval_chains, allow_destroy: true
  accepts_nested_attributes_for :policy_tenureships, allow_destroy: true

  validates_presence_of :name, :policy_type, :icon, :working_hours, :working_days
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_presence_of :accrual_rate_amount, :accrual_rate_unit, :rate_acquisition_period, :accrual_frequency, :allocate_accruals_at,
                        :start_of_accrual_period, :accrual_renewal_time, :tracking_unit, :first_accrual_method, :accrual_renewal_date, if: Proc.new { |policy| !policy.unlimited_policy? }
  validates :has_maximum_increment, :has_minimum_increment, inclusion: { in: [true, false] }
  validates_presence_of :max_accrual_amount, if: Proc.new { |policy| policy.has_max_accrual_amount? }
  validates_presence_of :accrual_period_start_date, if: Proc.new { |policy| policy.start_of_accrual_period == 'custom_start_date' }
  validates_presence_of :maximum_carry_over_amount, if: Proc.new { |policy| policy.has_maximum_carry_over_amount? && policy.carry_over_unused_timeoff}
  validates_presence_of :unlimited_type_title, if: Proc.new { |policy| policy.unlimited_policy }
  validates_presence_of :days_to_wait_until_auto_actionable, if: Proc.new { |policy| policy.manager_approval }
  validates_length_of :unlimited_type_title, maximum: 20
  validates_inclusion_of :for_all_employees, :manager_approval, in: [true, false]
  validates_inclusion_of :auto_approval, in: [true, false], if: Proc.new { |policy| policy.manager_approval }
  validates_inclusion_of :unlimited_policy, in: [true, false], on: :update
  validates :max_accrual_amount, numericality: true, if: Proc.new { |policy| policy.has_max_accrual_amount? }
  validates :accrual_period_start_date, numericality: true, if: Proc.new { |policy| policy.start_of_accrual_period == 'custom_start_date' }
  validates :maximum_carry_over_amount, numericality: true, if: Proc.new { |policy| policy.has_maximum_carry_over_amount? && policy.carry_over_unused_timeoff}
  validate :max_accrual_amount_is_possitive?
  validates_numericality_of :days_to_wait_until_auto_actionable
  validates_with PolicyEligibilityModificationValidator
  validate :working_hours_is_positive?
  validates_numericality_of :maximum_increment_amount, if: Proc.new { |policy| policy.has_maximum_increment == true}
  validates_numericality_of :minimum_increment_amount, if: Proc.new { |policy| policy.has_minimum_increment == true}
  validates_numericality_of :maximum_negative_amount, if: Proc.new { |policy| policy.can_obtain_negative_balance == true}
  validate :max_increment_is_greater_than_min, if: Proc.new { |policy| policy.has_maximum_increment == true && policy.has_minimum_increment == true}
  enum policy_type: {other: 0, vacation: 1, sick: 2, parental_leave: 3, jury_duty: 4, training: 5, study: 6, work_from_home: 7, out_of_office: 8, vaccination: 9}
  enum accrual_rate_unit: [:days, :hours]
  enum rate_acquisition_period: [:month, :week, :day, :hour_worked, :year]
  enum accrual_frequency: ['daily','weekly','bi-weekly','semi-monthly','monthly','annual']
  enum accrual_renewal_time: ['anniversary_date', '1st_of_january', 'custom_date']
  enum allocate_accruals_at: [:start, :end]
  enum start_of_accrual_period: [:hire_date, :custom_start_date]
  enum first_accrual_method: [:prorated_amount, :full_amount]
  enum tracking_unit: {hourly_policy: 0, daily_policy: 1}

  after_create :set_default_filters, if: Proc.new { |policy| policy.filter_policy_by.nil? }
  after_update :enabled_or_disabled_policies_for_users, if: proc { |policy| policy.saved_change_to_is_enabled? }
  after_update :set_accrual_start_of_assigned_policies, if: Proc.new { |policy| (policy.saved_change_to_start_of_accrual_period? ||  policy.saved_change_to_accrual_period_start_date? || policy.saved_change_to_accrual_frequency?) || policy_changed_to_limited? || policy.saved_change_to_allocate_accruals_at?}
  after_update :set_first_accrual_happening_date, if: Proc.new { |policy| period_info_and_frequency_updated? || policy_changed_to_limited?}
  after_update :reassigned_pto_policy_to_users, if: Proc.new { |policy| policy.is_enabled && !policy.assign_manually && policy.saved_change_to_filter_policy_by? }
  after_update :update_pto_calendar_events, if: Proc.new { |policy| policy.saved_change_to_policy_type? || policy.saved_change_to_display_detail? }
  after_commit :create_xero_leave, on: :create, if: Proc.new { |policy| policy.xero_leave_type_id.blank? }
  
  scope :enabled, -> { where(is_enabled: true) }
  scope :for_all_employees, -> { where(for_all_employees: true) }
  scope :limited_and_enabled, -> { where(is_enabled: true, unlimited_policy: false) }

  def self.assigned_default_pto_policies_or_by_filters team = nil, location= nil, employee_status = nil
  	where(is_enabled: true, assign_manually: false).where("(for_all_employees= ?) OR (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
  		(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
  		(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
  		(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
  		(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
  		(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
  		(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
  		(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?)",
  			true, '["all"]', '["all"]', '["all"]', location.to_s, employee_status.to_s, team.to_s, location.to_s, '["all"]', '["all"]', '["all"]',
  		  employee_status.to_s, '["all"]', '["all"]', '["all"]', team.to_s, location.to_s, employee_status.to_s, '["all"]', location.to_s, '["all"]',
  		  team.to_s, '["all"]', employee_status.to_s, team.to_s)
  end

  def self.get_policies_by_location(team, location, employee_status)
    enabled.where(for_all_employees: false, assign_manually: false)
    .where("(filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
      (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
      (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
      (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
      (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
      (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
      (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?) OR
      (filter_policy_by -> 'location' @> ? AND filter_policy_by -> 'employee_status' @> ? AND filter_policy_by -> 'teams' @> ?)",
      '["all"]', '["all"]', team.to_s,
      '["all"]', employee_status.to_s, '["all"]',
      location.to_s, '["all"]', '["all"]',
      '["all"]', employee_status.to_s, team.to_s,
      location.to_s, '["all"]', team.to_s,
      location.to_s, employee_status.to_s, '["all"]',
      location.to_s, employee_status.to_s, team.to_s,
      '["all"]', '["all"]', '["all"]')
  end

  def calculate_hours_used user_id
    requests = self.pto_requests.where(user_id: user_id, status: 1)
    hours_used = requests.inject(0) { |sum, p| sum + p.balance_hours }
  end

  def renewal_date date
    self.accrual_renewal_date.month > date.month || (self.accrual_renewal_date.month == date.month && self.accrual_renewal_date.day > date.day) ? change_year(self.accrual_renewal_date, date.year) : change_year(self.accrual_renewal_date, (date.year + 1))
  end

  def max_carryover_balance_hours
    self.maximum_carry_over_amount * self.working_hours
  end

  def get_unlimited_policy_title
    if self.unlimited_policy
      if self.unlimited_type_title.present?
        self.unlimited_type_title
      else
        I18n.t("admin.settings.pto_policies.unlimited")
      end
    end
  end

  def accrual_max_amount
    self.max_accrual_amount * self.working_hours
  end
 
  def available_hours user
    unless self.unlimited_policy
      policy = self.assigned_pto_policies.find_by_user_id(user.id)
      policy.present? ? policy.balance + policy.carryover_balance : 0
    end
  end

  def available_hours_with_carryover user
    ap = self.assigned_pto_policies.find_by(user_id: user.id)
    carryover = ''
    if ap.carryover_balance != 0
      carryover = self.tracking_unit == 'hourly_policy' ? " (#{ ap.carryover_balance } hours Rollover)" : " (#{(ap.carryover_balance/self.working_hours).round(2)} days Rollover)"
    end
    leftover = self.tracking_unit == "hourly_policy" ? "#{ap.total_balance.round(2)} hours" : "#{(ap.total_balance/self.working_hours).round(2)} days"
    leftover + carryover
  end

  def hours_used user
    (user.pto_requests.where(pto_policy_id: self.id).current_year_past_requests(user.company.time.to_date).sum(:balance_hours)).round(2)
  end

  def scheduled_hours user
    (user.pto_requests.where(pto_policy_id: self.id).upcoming_requests(self.company.time.to_date).sum(:balance_hours)).round(2)
  end

  def eoy_balance user_id
    return if self.unlimited_policy
    assigned_policy = self.assigned_pto_policies.where(user_id: user_id).first
    res = assigned_policy.present? ? Pto::PtoEstimateBalance.new(assigned_policy, self.company.time.to_date.end_of_year, self.company).perform : {estimated_balance: 0}
    res[:estimated_balance]
  end

  def balance_factor
    self.tracking_unit == "hourly_policy" ? 1 : self.working_hours 
  end

  def displaying_unit
    self.tracking_unit == "hourly_policy" ? "Hours" : "Days" 
  end

  private

  def destroy_pto_calendar_event id
    self.company.calendar_events.where(eventable_type: "PtoRequest", eventable_id: id).destroy_all if id
  end

  def max_accrual_amount_is_possitive?
    if self.max_accrual_amount.present? && self.max_accrual_amount < 0
      self.errors.add("The", I18n.t('errors.max_accrual_amount_error').to_s)
    end
  end

  def accrual_info_added_for_start_of_period?
    self.start_of_accrual_period == "hire_date" and self.changes_to_save["allocate_accruals_at"].present? and
    self.is_enabled == true and self.unlimited_policy == false
  end

  def period_info_and_frequency_updated?
    self.saved_changes["allocate_accruals_at"].present? or self.saved_changes["accrual_frequency"].present? or self.saved_changes["start_of_accrual_period"].present?
  end

  def set_first_accrual_happening_date
    self.assigned_pto_policies.where(is_balance_calculated_before: false).try(:each) do |assigned_policy|
      assigned_policy.set_first_accrual_happening_date
      set_balance_calculated_true assigned_policy.reload if policy_changed_to_limited?
    end
  end

  def set_accrual_start_of_assigned_policies
    self.assigned_pto_policies.where(is_balance_calculated_before: false).try(:each) do |assigned_policy|
      assigned_policy.set_accrual_start_date
    end
  end

  def enabled_or_disabled_policies_for_users
    if self.is_enabled
      TimeOff::AssignPtoPolicyToUsersJob.perform_in(5.second, {policy: self.id})
    else
      TimeOff::DisablePtoPolicyJob.perform_async(self.id)
    end
  end

  def reassigned_pto_policy_to_users
    TimeOff::ReassignPolicyOnFilterChangeJob.perform_in(5.seconds, self.id)
  end

  def set_default_filters
    self.update_columns(filter_policy_by: {location: ["all"], teams: ["all"], employee_status: ["all"]})
  end

  def update_pto_calendar_events
    TimeOff::UpdatePtoCalendarEvents.perform_in(5.second, {policy: self.id})
  end

  def policy_changed_to_limited?
    self.saved_changes["unlimited_policy"].present? && self.unlimited_policy == false
  end

  def set_balance_calculated_true assigned_policy
    assigned_policy.update_column(:is_balance_calculated_before, true) if  accrual_happening_date_of_past(assigned_policy)
  end

  def accrual_happening_date_of_past assigned_policy
    company_time = self.company.time
    ((include_todays_date(company_time) && assigned_policy.first_accrual_happening_date < company_time.to_date) || (!include_todays_date(company_time) && assigned_policy.first_accrual_happening_date <= company_time.to_date))
  end

  def include_todays_date(company_time)
    (self.allocate_accruals_at == "start" && company_time.hour < 8) || (self.allocate_accruals_at == "end" && company_time.hour < 19)
  end

  def working_hours_is_positive?
    self.errors.add(:policy, I18n.t('errors.working_hours_negative').to_s) if self.working_hours <= 0
  end

  def max_increment_is_greater_than_min
    if self.maximum_increment_amount.present? && self.minimum_increment_amount.present? && self.maximum_increment_amount < self.minimum_increment_amount
      self.errors.add(:base, I18n.t('errors.max_min').to_s)
    end
  end

  def create_xero_leave
    return if !self.company.is_xero_integrated?
    ::HrisIntegrations::Xero::CreateLeaveTypesInXero.perform_async(self.id)
  end
end
