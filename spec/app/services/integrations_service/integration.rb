require 'rails_helper'

RSpec.describe IntegrationsService::Integration do
  let(:company) { create(:company, subdomain: 'rocketship') }

  subject(:integration) { IntegrationsService::Integration.new(company) }

  describe 'update custom group mapping keys' do
    it 'updates mapping key' do
      company.update(department_mapping_key: 'Department#', location_mapping_key: 'Location#')
      company.reload

      integration.update_custom_group_mapping_keys

      company.reload
      expect(company.department_mapping_key).to eq('Department')
      expect(company.location_mapping_key).to eq('Location')
    end
  end

  describe 'removed preference field' do
    it 'removes preference field' do
      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Location' }.present?
      expect(status).to eq(true)

      integration.remove_preference_field('Location')

      default_fields = company.prefrences['default_fields']
      status = default_fields.select { |default_field| default_field['name'] == 'Location' }.present?
      expect(status).to eq(false)
    end
  end
end
