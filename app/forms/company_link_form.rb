class CompanyLinkForm < BaseForm
  attribute :name, String
  attribute :link, String
  attribute :position, Integer
  attribute :location_filters, Array[String]
  attribute :team_filters, Array[String]
  attribute :status_filters, Array[String]

  validates :name, :link, :position, :location_filters, :team_filters, :status_filters, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
end
