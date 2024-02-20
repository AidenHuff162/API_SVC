ActiveAdmin.register Logging, as: "Send Grid API Calls" do

  menu label: "Send Grid", parent: "Legacy Logging", priority: 2
  config.batch_actions = true
  permit_params :action, :result

  filter :company, collection: proc { Company.all_companies_alphabeticaly }
  filter :integration_name
  filter :state, label: "Response Code (i.e 200)", as: :select, multiple: true
  filter :action, label: "API Action", as: :string
  filter :api_request, label: "API Call Sent", as: :string
  filter :result, label: "API Response Received", as: :string
  filter :created_at
  actions :all, :except => [:edit]

  controller do
    def scoped_collection
      end_of_association_chain.where(integration_name: 'Send Grid')
    end
  end

  index do
    selectable_column
    id_column
    column :company
    column :integration_name
    column :action
    column :created_at
    column :api_request
    column :state
    actions
  end

  show  :title => proc{|api_call| "API Call ##{api_call.id}" } do
    attributes_table do
      row :company
      row :integration_name
      row :action
      row :created_at
      row :api_request
      row :result
    end
  end


  form do |f|
    f.semantic_errors *f.object.errors.keys
    f.inputs "API Call" do
      f.input :action
    end
    f.actions
  end

end
