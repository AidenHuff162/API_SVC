ActiveAdmin.register CustomField, as: "Greenhouse CF" do

  menu label: "Greenhouse CF", parent: "Integrations"

  config.batch_actions = false
  JSON :partial => 'custom_table_index'
  JSON :partial => 'custom_field_index'
  permit_params :ats_mapping_key, :ats_integration_group, :ats_mapping_section, :ats_mapping_field_type

  filter :name
  filter :company, collection: proc { Company.all_companies_alphabeticaly }
  filter :section
  filter :created_at
  filter :updated_at

  collection_action :custom_table_index, format: :json do
    custom_tables = CustomTable.where(company_id: params[:company_id]).pluck(:name, :id)
    render json: custom_tables.as_json
  end

  collection_action :custom_field_index, format: :json do
    if params[:is_profile_field]
      custom_fields = end_of_association_chain.where(company_id: params[:company_id], section: CustomField.sections[params[:section]])
    elsif params[:is_custom_table]
      custom_fields = end_of_association_chain.where(company_id: params[:company_id], custom_table_id: params[:custom_table_id])
    else
      custom_fields = end_of_association_chain.where(ats_integration_group: CustomField.ats_integration_groups[:greenhouse]).where(deleted_at: nil)
    end

    render json: custom_fields.as_json
  end

  controller do
    def scoped_collection
      if params[:is_profile_field]
        custom_fields = end_of_association_chain.where(company_id: params[:company_id], section: CustomField.sections[params[:section]])
      elsif params[:is_custom_table]
        custom_fields = end_of_association_chain.where(company_id: params[:company_id], custom_table_id: params[:custom_table_id])
      else
        custom_fields = end_of_association_chain.where(ats_integration_group: CustomField.ats_integration_groups[:greenhouse]).where(deleted_at: nil)
      end

      custom_fields
    end

    def destroy
      custom_field = CustomField.find_by_id(params['id'])
      custom_field.update!(ats_mapping_section: nil, ats_integration_group: nil, ats_mapping_field_type: nil, ats_mapping_key: nil)
      redirect_to action: 'index'
    end

    def update
      params[:custom_field].delete(:name)
      update!
    end

    def create
      custom_field_params = params[:custom_field]

      custom_field = CustomField.where(id: custom_field_params[:name], company_id: custom_field_params[:company_id]).take rescue nil
      custom_field.update!(ats_mapping_section: custom_field_params['ats_mapping_section'], ats_integration_group: CustomField.ats_integration_groups[:greenhouse],
        ats_mapping_field_type: custom_field_params['ats_mapping_field_type'], ats_mapping_key: custom_field_params['ats_mapping_key'])

      redirect_to action: 'index'
    end
  end

  index do
    selectable_column
    id_column
    column :name
    column :company
    actions
  end

  show do
    attributes_table do
      row :name
      row :company
      row :section
      row :ats_mapping_section
      row :ats_mapping_key
      row :field_type
      row :ats_mapping_field_type
      row :created_at
      row :updated_at
    end
  end

  form html: {id: "greenhouse_custom_field", data: {parsley_validate: true} } do |f|
    f.inputs "Greenhouse Custom Field Details" do
      companies = Company.joins(:integration_instances).where(:integration_instances => {api_identifier: "green_house"})
      if companies.present?
        if !params[:id]
          f.input :company, as: :select, :collection => companies.all_companies_alphabeticaly, include_blank: false, allow_blank: false
          f.input :profile_setup, as: :select, :collection => [['Profile Fields', 'profile_fields'], ['Custom Table', 'custom_table']], include_blank: false, allow_blank: false
          f.input :section, include_blank: false, allow_blank: false
          f.input :custom_table, as: :select, :collection => [], include_blank: false, allow_blank: false
          f.input :name, as: :select, :collection => [], allow_blank: false, input_html: {required: ''}
        else
          f.input :company, input_html: { disabled: true }
          custom_field = CustomField.find_by_id(params[:id])
          default_profile_setup = (custom_field.custom_table_id) ? 'custom_table' : 'profile_fields'
          f.input :profile_setup, as: :select, :collection => [['Profile Fields', 'profile_fields'], ['Custom Table', 'custom_table']], include_blank: false, allow_blank: false, selected: default_profile_setup, input_html: { disabled: true }
          if custom_field.custom_table_id
            custom_tables = CustomTable.where(company_id: custom_field.company_id).pluck(:name, :id)
            f.input :custom_table, as: :select, :collection => custom_tables, include_blank: false, allow_blank: false, selected: custom_field.custom_table_id, input_html: { disabled: true }
            custom_fields = custom_field.custom_table.custom_fields.pluck(:name, :id)
            f.input :name, as: :select, :collection => custom_fields, include_blank: false, allow_blank: false, selected: custom_field.id, input_html: { disabled: true }
          else
            f.input :section, input_html: { disabled: true }
            custom_fields = custom_field.company.custom_fields.where(section: CustomField.sections[custom_field.section]).pluck(:name, :id)
            f.input :name, as: :select, :collection => custom_fields, selected: custom_field.id, include_blank: false, allow_blank: false, input_html: { disabled: true }
          end
        end

        f.input :field_type, input_html: { disabled: true }
        f.input :ats_mapping_section, include_blank: false, allow_blank: false
        f.input :ats_mapping_key, input_html: {required: ''}
        f.input :ats_mapping_field_type, as: :select, :collection =>  CustomField.field_types.keys.map { |w| [w.humanize, w] }, include_blank: false, allow_blank: false

        f.actions
      end
    end
  end
end
