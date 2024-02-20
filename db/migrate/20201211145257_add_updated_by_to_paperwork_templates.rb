class AddUpdatedByToPaperworkTemplates < ActiveRecord::Migration[5.1]
  def change
    add_reference :paperwork_templates, :updated_by, index: true
  end
end
