class AddCosignerTypeToPaperworkRequest < ActiveRecord::Migration[5.1]
  def change
    add_column :paperwork_requests, :co_signer_type, :integer
  end
end
