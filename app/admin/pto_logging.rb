ActiveAdmin.register Logging, as: "PTO Logging" do

  menu label: "PTO Logs", parent: "Legacy Logging"

  config.batch_actions = false
  filter :company, collection: proc { Company.all_companies_alphabeticaly }
  filter :result, as: :string
  filter :created_at
  filter :action, as: :string
  actions :all, :except => [:edit, :new]

  controller do
    def scoped_collection
      end_of_association_chain.where(action: ['Deduct Balance', 'PTO Calculations', 'Auto Complete', 'Slack PTO Creation'])
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
