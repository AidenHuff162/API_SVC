module Integrations
  class MigrateCustomFieldDataToAnotherCustomFieldJob < ApplicationJob
    queue_as :manage_custom_field_data_migration

    def perform(company_id = nil, custom_field_name = nil, options = [])
      return unless company_id.present? && custom_field_name.present?

      company = Company.find_by(id: company_id)
      return unless company.present?

      CustomFieldsService.new(company).migrate_custom_field_data_to_another_custom_field(custom_field_name, options)
    end
  end
end
