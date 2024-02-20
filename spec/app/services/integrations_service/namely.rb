require 'rails_helper'

RSpec.describe IntegrationsService::Namely do
  let(:company) { create(:company, subdomain: 'rocketship') }

  subject(:namely) { IntegrationsService::Namely.new(company) }

  describe '#manage profile setup' do
    it 'manages adp workforce now to namely changeover' do
      company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).destroy_all
      company.integrations.create!(api_name: "ADP-WFN", company_id: company.id)

      custom_groups = CustomField.where(company_id: company.id, name: 'Business Unit')
      expect(custom_groups.count).to eq(1)
      expect(custom_groups.where(deleted_at: nil).count).to eq(1)

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(false)

      namely.manage_profile_setup_on_integration_change

      custom_groups = CustomField.where(company_id: company.id, name: 'Business Unit')
      expect(custom_groups.count).to eq(1)
      expect(custom_groups.where.not(deleted_at: nil).count).to eq(0)
      expect(custom_groups.where(deleted_at: nil).count).to eq(1)


      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(true)
    end

    it 'manages bamboo to namely changeover' do
      company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).destroy_all
      company.integrations.create!(api_name: "bamboo_hr", company_id: company.id)

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(false)

      custom_groups = CustomField.where(company_id: company.id, name: 'Division')
      expect(custom_groups.count).to eq(1)

      namely.manage_profile_setup_on_integration_change

      custom_groups = CustomField.where(company_id: company.id, name: 'Division')
      expect(custom_groups.count).to eq(1)
      expect(custom_groups.where.not(deleted_at: nil).count).to eq(0)
      expect(custom_groups.where(deleted_at: nil).count).to eq(1)

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(true)
    end

    it 'manages paylocity to namely changeover' do
      company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).destroy_all

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(false)

      namely.manage_profile_setup_on_integration_change

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(true)
    end

    it 'manages no integration to namely changeover' do
      company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).destroy_all

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(false)

      namely.manage_profile_setup_on_integration_change

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Job Tier' }.present?
      expect(status).to eq(true)
    end

    it 'manages adp workforce now and bamboo to bamboo' do
      company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).destroy_all
      company.integrations.create!(api_name: "bamboo_hr", company_id: company.id)
      company.integrations.create!(api_name: "ADP-WFN", company_id: company.id)

      custom_groups = CustomField.where(company_id: company.id, name: ['Business Unit', 'Division'])
      expect(custom_groups.count).to eq(2)
      expect(custom_groups.where(deleted_at: nil).count).to eq(2)

      namely.manage_profile_setup_on_integration_change

      custom_groups = CustomField.where(company_id: company.id, name: ['Business Unit', 'Division'])
      expect(custom_groups.count).to eq(2)
      expect(custom_groups.where.not(deleted_at: nil).count).to eq(0)

      custom_fields = CustomField.where(company_id: company.id, name: 'Pay Frequency')
      expect(custom_fields.count).to eq(1)
      custom_field_options = custom_fields.first.custom_field_options.pluck(:option)
      expect(custom_field_options.count).to eq(5)

      custom_fields = CustomField.where(company_id: company.id, name: 'Rate Type')
      expect(custom_fields.count).to eq(1)
      custom_field_options = custom_fields.first.custom_field_options.pluck(:option)
      expect(custom_field_options.count).to eq(3)

      custom_fields = CustomField.where(company_id: company.id, name: 'Pay Rate')
      expect(custom_fields.count).to eq(1)
      expect(custom_fields.take.field_type).to eq('currency')
    end
  end
end
