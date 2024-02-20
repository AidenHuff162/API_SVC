require 'rails_helper'

RSpec.describe IntegrationFieldMapping, type: :model do

  let(:company) { create(:company) }
  let!(:kallidus_inventory) { FactoryGirl.create(:kallidus_learn_integration_inventory) }
  let!(:integration_instance) { create(:kallidus_learn, integration_inventory_id: kallidus_inventory.id, company_id: company.id) }
  

  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:integration_instance) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validates presence of' do
    it 'field id should be present' do
      mapping = FactoryGirl.create(:integration_field_mapping, integration_instance: integration_instance, company: company)
      expect(mapping.custom_field_id || mapping.preference_field_id).to be_present
    end

    it 'integration instance id should be present' do
      mapping = FactoryGirl.create(:integration_field_mapping, integration_instance: integration_instance, company: company)
      expect(mapping.integration_instance_id).to be_present
    end

    it 'company id should be present' do
      mapping = FactoryGirl.create(:integration_field_mapping, integration_instance: integration_instance, company: company)
      expect(mapping.company_id).to be_present
    end

    it 'field position should be present' do
      mapping = FactoryGirl.create(:integration_field_mapping, integration_instance: integration_instance, company: company)
      expect(mapping.field_position).to be_present
    end
  end

  describe 'uniqueness validation' do
    it 'Exception if company id, integration instance id, field position, field id are same' do
      mapping = FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test', preference_field_id: 'fe', field_position: 1, company_id: company.id, integration_instance_id: integration_instance.id)
      expect { FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test', preference_field_id: 'fe', field_position: 1, company_id: company.id, integration_instance_id: integration_instance.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end