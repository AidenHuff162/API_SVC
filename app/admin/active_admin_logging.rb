ActiveAdmin.register ActiveAdminLogging, as: "Active Admin Logs" do

  menu label: "Active Admin Logs", parent: "Loggings"

  permit_params :action

  filter :admin_user_id
  filter :created_at
  actions :all, :except => [:edit, :delete, :create, :show, :destroy]

  index do
    selectable_column
    id_column
    column :created_at
    column :admin_user
    column :action
    column :user
    column :company
    column :company_email
    column :version
    actions
  end

end
