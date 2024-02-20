class CustomFieldForm < BaseForm
  presents :custom_field
  PLURAL_RELATIONS = %i(custom_field_options)

  attribute :id, Integer
  attribute :name, String
  attribute :company_id, Integer
  attribute :field_type, Integer
  attribute :skip_validations, Boolean
  attribute :custom_field_options, Array[CustomFieldOptionForm]
end
