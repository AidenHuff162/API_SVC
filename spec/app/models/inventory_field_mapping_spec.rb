require 'rails_helper'

RSpec.describe InventoryFieldMapping, type: :model do

  let(:company) { create(:company) }
  let!(:paylocity_integration_inventory) { FactoryGirl.create(:paylocity_integration_inventory) }
  
  describe 'Associations' do
    it { is_expected.to belong_to(:integration_inventory) }
  end

  describe 'uniqueness validation' do
    it 'Exception if inventory id and integration_field_key are same' do
      mapping = FactoryGirl.create(:inventory_field_mapping, inventory_field_key: 'test', integration_inventory_id: paylocity_integration_inventory.id)
      expect { FactoryGirl.create(:inventory_field_mapping, inventory_field_key: 'test', integration_inventory_id: paylocity_integration_inventory.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end