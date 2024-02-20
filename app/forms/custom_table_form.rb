class CustomTableForm < BaseForm
  presents :custom_table
  PLURAL_RELATIONS = %i(custom_fields)

  attribute :id, Integer
  attribute :name, String
  attribute :table_type, Integer
  attribute :company_id, Integer
  attribute :position, Integer
  attribute :custom_fields, Array[CustomFieldForm]

end
