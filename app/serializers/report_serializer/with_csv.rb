module ReportSerializer
  class WithCSV < ActiveModel::Serializer
    attributes :id, :name, :meta, :permanent_fields, :last_view
    has_many :custom_field_reports
  end
end
