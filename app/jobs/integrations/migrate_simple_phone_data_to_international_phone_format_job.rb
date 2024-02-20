module Integrations
  class MigrateSimplePhoneDataToInternationalPhoneFormatJob < ApplicationJob
    queue_as :manage_phone_format_conversion

    def perform(company_id = nil, custom_field_id = nil)
      return unless company_id.present? && custom_field_id.present?

      company = Company.find_by(id: company_id)
      return unless company.present?

      custom_field = company.custom_fields.find_by(id: custom_field_id)
      return unless custom_field.present?

      CustomFieldsService.new(company).migrate_simple_phone_data_to_international_phone_format(custom_field)
    end
  end
end
