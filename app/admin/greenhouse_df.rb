ActiveAdmin.register Company, as: "Greenhouse DF" do

  menu label: "Greenhouse DF", parent: "Integrations"

  actions :all, :except => [:destroy, :create]
  permit_params :prefrences

  json_editor

  config.batch_actions = false

  filter :name
  filter :created_at
  filter :updated_at

  controller do
    def scoped_collection
      end_of_association_chain.where(deleted_at: nil).includes(:integration_instances).where(:integration_instances=>{:api_identifier=>'green_house'})
    end
  end

  index do
    selectable_column
    id_column
    column :name
    actions
  end

  show do
    attributes_table do
      row :name
      row :prefrences
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      f.input :prefrences, as: :jsonb
    end

    f.actions
  end
end
