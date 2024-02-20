class ChangeDefaultStateForUserDocument < ActiveRecord::Migration[5.1]
  def change
  	change_column_default :user_document_connections, :state, "draft"
  end
end
