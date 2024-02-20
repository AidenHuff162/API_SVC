class CustomFieldOptionForm < BaseForm
  presents :custom_field_option
  PLURAL_RELATIONS = %i(custom_field_values)

  attribute :id, Integer
  attribute :option, String
  attribute :owner_id, Integer
  attribute :description, String
  attribute :custom_field_id, Integer
  attribute :custom_field_values, Array[CustomFieldValueForm]
  attribute :active, Boolean
end
