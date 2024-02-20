class InventoryFieldMapping < ActiveRecord::Base
  belongs_to :integration_inventory
  
  validates :inventory_field_key, uniqueness: {scope: [:inventory_field_key, :integration_inventory_id], message: 'Inventory Field Mapping Uniqueness Constraint Violated.'}

end  
