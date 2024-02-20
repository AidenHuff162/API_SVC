class AddPaylocityGroupIdToCustomFieldOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :custom_field_options, :paylocity_group_id, :string
  end
end
