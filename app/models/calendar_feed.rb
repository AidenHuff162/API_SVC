class CalendarFeed < ApplicationRecord
  include UserStatisticManagement

  has_paper_trail
  belongs_to :company
  belongs_to :user

  validates :feed_type, uniqueness: { scope: :user_id }

  scope :by_feed_types, ->(types, company_id) { where(feed_type: types, company_id: company_id) }

  before_save :initialize_calendar_feeds_param

  enum feed_type: {
    start_date: 0,
    birthday: 1,
    overdue_activity: 2,
    offboarding_date: 3,
    anniversary: 4,
    out_of_office: 5,
    holiday: 6
  }

  # @return feed types as per company plan
  def self.allowed_feed_types(current_company)
    feed_types = %i[start_date overdue_activity offboarding_date holiday]
    feed_types.push(:anniversary, :birthday) if current_company.people_operations?

    if current_company.enabled_time_off && current_company.calendar_feed_syncing_feature_flag
      feed_types << :out_of_office
    end

    feed_types
  end

  # @return feeds as per company plan
  def self.allowed_calendar_feeds(current_company, calendar_feed_id)
    feed_types = allowed_feed_types(current_company)
    CalendarFeed.by_feed_types(feed_types, current_company.id).find_by(feed_id: calendar_feed_id)
  end

  private

  def initialize_calendar_feeds_param
    self.feed_id = SecureRandom.hex + Time.now.to_i.to_s
    self.feed_url = "https://#{self.company.domain}/api/v1/calendar_feeds/feed?id=#{self.feed_id}"
  end
end
