class AddPositionToPtoPolicies < ActiveRecord::Migration[5.1]
  def change
    add_column :pto_policies, :position, :integer, default: 0
  end
end
