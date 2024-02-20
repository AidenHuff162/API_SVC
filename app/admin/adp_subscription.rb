ActiveAdmin.register AdpSubscription, as: "ADP Subscriptions" do

  config.batch_actions = true
  actions :all, :except => [:new, :create, :edit]

  index do
    selectable_column
    id_column
    column :env
    column :event_type
    column :company_name
    column :organization_oid
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :event_type
      row :subscriber_first_name
      row :subscriber_last_name
      row :subscriber_email
      row :subscriber_uuid
      row :company_name
      row :company_uuid
      row :organization_oid
      row :no_of_users
      row :associate_oid
      row :created_at
      row :updated_at
    end
  end
end