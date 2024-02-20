class ReportsMandatoryFieldsValidator < ActiveModel::Validator
  def validate record
    return true if ['workflow', 'document', 'survey'].include?(record.report_type)
    report_fields = record.permanent_fields.count + record.custom_tables.count + record.custom_field_reports.count + record.meta['other_section'].to_a.count
    return true if report_fields > 0
    
    record.errors.add(:base, 'Mandatory fields are missing')
  end
end
