class AddEnumCompanyPlanstoCompanies < ActiveRecord::Migration[5.1]
  def change
  	add_column :companies, :company_plan, :integer, default: 0
  end
end
