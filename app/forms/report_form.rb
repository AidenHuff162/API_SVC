class ReportForm < BaseForm
  PLURAL_RELATIONS = %i(custom_field_reports)

  attribute :id, Integer
  attribute :name, String
  attribute :meta, JSON
  attribute :permanent_fields, JSON
  attribute :last_view, DateTime
  attribute :custom_field_reports, Array[CustomFieldReportForm]
  attribute :company_id, Integer
  attribute :user_id, Integer
  attribute :user_role_ids, Array[String]
  attribute :report_creator_id, Integer
  attribute :report_type, Integer
  attribute :custom_tables, JSON
  attribute :sftp_id, Integer

  validates :name, :user_id, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_with ReportsMandatoryFieldsValidator
end
