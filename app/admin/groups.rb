ActiveAdmin.register CustomField, as: "Groups" do

  menu label: "Groups", parent: "Company", priority: 3

  config.batch_actions = false
  permit_params :name, :company_id, :section, :field_type, :help_text, :required,
                :collect_from, :mapping_key, :integration_group

  filter :name
  filter :company, collection: proc { Company.all_companies_alphabeticaly }
  filter :section
  filter :created_at
  filter :updated_at

  controller do
    def scoped_collection
      end_of_association_chain.where.not(integration_group: 0).where(deleted_at: nil)
    end

    def create
      company = Company.find_by(id: params[:custom_field][:company_id])
      params[:custom_field].merge!(field_type: 4, integration_group: CustomField.integration_groups[:custom_group], display_location: 2)
      create!
    end
  end

  index do
    selectable_column
    id_column
    column :name
    column :company
    column :section
    column :mapping_key
    actions
  end

  show do
    attributes_table do
      row :name
      row :company
      row :section
      row :mapping_key
      row :created_at
      row :updated_at
    end
  end

  form html: {id: "custom_field", data: {parsley_validate: true} } do |f|
    f.inputs "Group Field Details" do
      f.input :name, input_html: {required: ''}
      f.input :company, input_html: {required: ''}, as: :select, :collection => Company.all.distinct.all_companies_alphabeticaly.pluck(:name, :id)
      f.input :section, input_html: {required: ''}
      f.input :mapping_key, input_html: {required: ''}
    end
    f.actions
  end
end
