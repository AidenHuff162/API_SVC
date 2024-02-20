class CompanyValueForm < BaseForm
  SINGULAR_RELATIONS = %i(company_value_image)

  attribute :name, String
  attribute :description, String
  attribute :company_value_image, UploadedFileForm::CompanyValueImageForm
  attribute :position, Integer

  validates :name, :description, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE)
end
