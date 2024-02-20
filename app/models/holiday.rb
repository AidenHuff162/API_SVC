class Holiday < ApplicationRecord
  include CalendarEventsCrudOperations
  acts_as_paranoid
  has_paper_trail

  validates :begin_date, :name, presence: true
  belongs_to :company
  has_one :calendar_event, as: :eventable, dependent: :destroy
  before_save :set_end_date, unless: :end_date
  after_commit :update_pto_requests_balance, on: :create
  after_update :update_pto_requests_balance, :changes_in_date_or_filters?
  after_destroy {update_pto_requests_balance(true)}
  after_create :holiday_calendar_event , if: Proc.new { |c| c.company.enabled_calendar == true}
  after_update :update_holiday_event , if: Proc.new { |c| c.company.enabled_calendar == true}
  def holiday_calendar_event
    setup_calendar_event(self, 'holiday', self.company)
  end

  def update_holiday_event
    update_holiday_calendar_event(self)
  end

  private

  def changes_in_date_or_filters?
    self.saved_change_to_begin_date? || self.saved_change_to_end_date? || self.saved_change_to_status_permission_level? || self.saved_change_to_team_permission_level? || self.saved_change_to_location_permission_level?
  end

  def update_pto_requests_balance destroyed=false
    if self.begin_date > self.company.time.to_date && self.company.enabled_time_off
      if destroyed
        TimeOff::UpdatePtoRequestsBalanceOnHolidayCreation.perform_at(5.seconds.from_now, nil, self.attributes)
      else
        TimeOff::UpdatePtoRequestsBalanceOnHolidayCreation.perform_at(5.seconds.from_now, self.id)
      end
    end
  end

  def set_end_date
    self.end_date = self.begin_date
  end

end
