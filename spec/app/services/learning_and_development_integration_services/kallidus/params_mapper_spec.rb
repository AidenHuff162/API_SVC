require 'rails_helper'

RSpec.describe LearningAndDevelopmentIntegrationServices::Kallidus::ParamsMapper do
  let(:company) { create(:company) }
  let!(:kallidus_inventory) { FactoryGirl.create(:kallidus_learn_integration_inventory) }
  let!(:integration_instance) { create(:kallidus_learn, integration_inventory_id: kallidus_inventory.id, company_id: company.id) }
  let!(:field1) { FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test', integration_instance_id: integration_instance.id, company_id: integration_instance.company_id, field_position: 1) }
  let!(:field2) { FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test1', integration_instance_id: integration_instance.id, company_id: integration_instance.company_id, field_position: 2) }
  let!(:field3) { FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test2', integration_instance_id: integration_instance.id, company_id: integration_instance.company_id, field_position: 3) }
  let!(:field4) { FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test3', integration_instance_id: integration_instance.id, company_id: integration_instance.company_id, field_position: 4) }

  describe 'Params Mapper Hash Should be Created' do
    context 'Fields Mappings Should be created' do
      it 'Should Create Field Mappings' do
        FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test', integration_instance_id: integration_instance.id, company_id: integration_instance.company_id)
        expect(integration_instance.integration_field_mappings.where(integration_field_key: 'test').take.present?).to eq(true)
      end

      it 'should Retreive Field Mappings' do
        FactoryGirl.create(:integration_field_mapping, integration_field_key: 'test', integration_instance_id: integration_instance.id, company_id: integration_instance.company_id)
        params_hash = ::LearningAndDevelopmentIntegrationServices::Kallidus::ParamsMapper.new.build_parameter_mappings(company.subdomain, integration_instance)
        expect(params_hash.class).to eq(Hash)
      end

      it 'should Retreive Field Mappings according to field position' do
        params_hash = ::LearningAndDevelopmentIntegrationServices::Kallidus::ParamsMapper.new.build_parameter_mappings(company.subdomain, integration_instance)
        expect(params_hash.count).to eq(14)
        expect(params_hash.keys).to eq([:test, :firstName, :test1, :importKey, :lastName, :test2, :test3, :userName, :emailAddress, :startDate, :isEnabled, :leaveDate, :jobTitle, :managerImportKey])
        expect(params_hash.class).to eq(Hash)
      end
    end
  end
end 