class AddSaDisableToCompanies < ActiveRecord::Migration[5.1]
  def change
    add_column :companies, :sa_disable, :boolean, default: true
  end
end
