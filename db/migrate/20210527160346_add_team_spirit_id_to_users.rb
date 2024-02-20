class AddTeamSpiritIdToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :team_spirit_id, :string
  end
end
