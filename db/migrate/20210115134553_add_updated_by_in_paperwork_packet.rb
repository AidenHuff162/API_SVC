class AddUpdatedByInPaperworkPacket < ActiveRecord::Migration[5.1]
  def change
    add_reference :paperwork_packets, :updated_by, index: true, foreign_key: { to_table: :users }
  end
end
