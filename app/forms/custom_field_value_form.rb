class CustomFieldValueForm < BaseForm
  presents :custom_field_value

  attribute :id, Integer
  attribute :custom_field_id, Integer
  attribute :custom_field_option_id, Integer
  attribute :user_id, Integer
end
