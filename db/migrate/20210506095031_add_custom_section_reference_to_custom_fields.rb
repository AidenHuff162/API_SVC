class AddCustomSectionReferenceToCustomFields < ActiveRecord::Migration[5.1]
  def change
    add_reference :custom_fields, :custom_section, foreign_key: true
  end
end
