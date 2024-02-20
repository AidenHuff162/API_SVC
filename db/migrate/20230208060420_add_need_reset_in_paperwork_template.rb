class AddNeedResetInPaperworkTemplate < ActiveRecord::Migration[6.0]
  def change
    add_column :paperwork_templates, :need_reset, :boolean, default: nil
  end
end
