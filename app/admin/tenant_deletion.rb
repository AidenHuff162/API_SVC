ActiveAdmin.register Logging, as: "Tenant Deletion" do

  menu label: "Tenant Deletion", parent: "Legacy Logging"

  config.batch_actions = false
  filter :company, collection: proc { Company.all_companies_alphabeticaly }
  filter :result, as: :string
  filter :created_at
  filter :action, as: :string
  actions :all, :except => [:edit, :create]

  controller do
    def scoped_collection
      end_of_association_chain.where(action: ['Tenant Deletion'])
    end
  end

  index do
    selectable_column
    id_column
    column :company
    column :action
    column :created_at
    column :result
    actions
  end
end
