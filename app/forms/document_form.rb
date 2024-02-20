class DocumentForm < BaseForm

  SINGULAR_RELATIONS = %i(attached_file)

  attribute :title, String
  attribute :description, String
  attribute :meta, JSON
  attribute :attached_file, UploadedFileForm::DocumentFileForm
  attribute :company_id, Integer

  validates :company_id, :title, :description, :attached_file, presence: true
  validates_format_of :title, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE)
end
