ActiveAdmin.register Blazer::Audit, as: "Blazer Logs" do
  
  menu label: "Blazer Logs", parent: "Loggings"

  config.batch_actions = true
  permit_params :action, :result

  filter :user_id
  filter :created_at
  actions :all, :except => [:edit, :delete, :create, :show]

  index do
    selectable_column
    id_column
    column :user
    column :statement
    column :query
    column :created_at
    actions
  end

end
