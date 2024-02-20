class HolidayForm < BaseForm
  presents :holiday

  attribute :name, String
  attribute :company_id, Integer
  attribute :begin_date, Date
  attribute :end_date, Date
  attribute :multiple_dates, Boolean
  attribute :created_by_id, Integer
  attribute :team_permission_level, Array[String]
  attribute :location_permission_level, Array[String]
  attribute :status_permission_level, Array[String]

  validates :name, :begin_date, :created_by_id, :company_id, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
end
