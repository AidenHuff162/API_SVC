ActiveAdmin.register Logging, as: "Custom Table Loggings" do

  menu label: "Custom Table Logs", parent: "Legacy Logging", priority: 12

  config.batch_actions = true
  permit_params :action, :result

  filter :action
  filter :company, collection: proc { Company.where(deleted_at: nil) }
  filter :api_request, label: "Custom Table Loggings", as: :string
  filter :created_at
  actions :all, :except => [:edit, :delete]

  controller do
    def scoped_collection
      end_of_association_chain.where(action: ['Assign Values To User - Pass', 'Assign Values To User - Fail', 'cancel-offboarding', 'User - OffboardUserJob', 'Destroyed Scheduled Email', 'Schedule Email', 'Destroy incomplete Email', 'User - ReassignManagersJob', 'Auto Approving Request'])
    end
	end

  index do
    selectable_column
    id_column
    column :company
    column :action
    column :created_at
    column :api_request
    actions
  end

  show  :title => proc{|custom_table_logging| "Custom Table Logging ##{custom_table_logging.id}" } do
    attributes_table do
      row :company
      row :action
      row :api_request
      row :result
      row :created_at
    end
  end

  form do |f|
    f.semantic_errors *f.object.errors.keys
    f.inputs "Custom Table Logging" do
      f.input :action
    end
    f.actions
  end
end
