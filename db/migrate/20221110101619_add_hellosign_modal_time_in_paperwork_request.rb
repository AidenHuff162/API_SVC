class AddHellosignModalTimeInPaperworkRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :paperwork_requests, :hellosign_modal_opened_at, :datetime
  end
end
