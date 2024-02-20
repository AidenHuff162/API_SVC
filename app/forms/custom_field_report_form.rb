class CustomFieldReportForm < BaseForm
  presents :custom_fields_report
  attribute :id, Integer
  attribute :custom_field_id, Integer
  attribute :report_id, Integer
  attribute :position, Integer
end
