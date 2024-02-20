class MilestoneForm < BaseForm
  SINGULAR_RELATIONS = %i(milestone_image)

  attribute :happened_at, Date
  attribute :name, String
  attribute :description, String
  attribute :milestone_image, UploadedFileForm::MilestoneImageForm
  attribute :position, Integer

  validates :name, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
end
