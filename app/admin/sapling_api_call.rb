ActiveAdmin.register ApiLogging, as: "Sapling API Calls" do

  menu label: "Public API", parent: "Legacy Logging", priority: 3

  config.batch_actions = true
  permit_params :action, :result

  filter :company, collection: proc { Company.all_companies_alphabeticaly }
  filter :status, label: "Status", as: :string
  filter :message
  filter :created_at
  actions :all, :except => [:edit]

  index do
    selectable_column
    id_column
    column :company
    column :end_point, label: "Sapling API Endpoint"
    column :message
    column :status
    column :created_at
    actions
  end

  show  :title => proc{|api_call| "API Call ##{api_call.id}" } do
    attributes_table do
      row :company
      row :api_key
      row :end_point
      row :message
      row :status
      row :data
      row :created_at
    end
  end
end
