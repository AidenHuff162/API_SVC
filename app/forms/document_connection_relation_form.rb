class DocumentConnectionRelationForm < BaseForm

  attribute :title, String
  attribute :description, String

  validates :title, :description, presence: true
  validates_format_of :title, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE)
end
