ActiveAdmin.register IntegrationFieldMapping do
  config.sort_order = 'field_position_asc'
  menu label: "Kallidus Learn", parent: "Integrations"

  config.batch_actions = false
  JSON :partial => 'custom_fields'
  JSON :partial => 'integration_instances'
  JSON :partial => 'field_position'
  config.filters = true

  permit_params :integration_field_key, :custom_field_id, :preference_field_id,
          :is_custom, :exclude_in_update, :exclude_in_create, :parent_hash, :parent_hash_path,
          :integration_instance_id, :company_id, :field_position

  actions :all
  config.remove_action_item(:new)

  action_item :add_new_mapping, only: :index do
    link_to "ADD NEW FIELD Mapping", new_admin_integration_field_mapping_path, method: :get 
  end

  filter :company, label: 'Company', collection: proc { Company.all_companies_alphabeticaly }
  filter :field_name_filter, label: "Name", as: :string
  filter :created_at
  filter :updated_at

  collection_action :integration_instances, format: :json do
    integration_instances = Company.find_by(id: params[:company_id]).integration_instances.where(api_identifier: 'kallidus_learn')
    render json: integration_instances.as_json
  end

  collection_action :custom_fields, format: :json do
    custom_fields = Company.find_by(id: params[:company_id]).custom_fields.where(deleted_at: nil)
    prefrences = Company.find_by(id: params[:company_id]).prefrences['default_fields']
    all_fields = prefrences + custom_fields
    render json: all_fields.as_json
  end

  collection_action :field_position, format: :json do
    if params[:integration_field_mapping_id].present?
      field_position = IntegrationFieldMapping.find_by(id: params[:integration_field_mapping_id])&.field_position
    else
      field_position = IntegrationFieldMapping.where(company_id: params['company_id']).pluck(:field_position).max + 1 rescue 1
    end
    
    render json: field_position.as_json
  end

  controller do

    def index
      @page_title="Kallidus Learn Field Mapping"
      IntegrationFieldMapping.unscoped {super}
	  end

    def show
      current_admin_user.active_admin_loggings.create!(action: "Viewed Integration Field Mapping with id #{params[:id]}")
      IntegrationFieldMapping.find_by(id: params[:id])
    end

    def edit
      current_admin_user.active_admin_loggings.create!(action: "Edited Integration Field Mapping with id #{params[:id]}")
      IntegrationFieldMapping.find_by(id: params[:id])
    end

    def update
      current_admin_user.active_admin_loggings.create!(action: "Updated Integration Field Mapping with id #{params[:id]}")
      integration_field_mapping = IntegrationFieldMapping.find_by_id(params[:id])
      query = integration_field_mapping.company.integration_field_mappings.where(field_position: params['integration_field_mapping']['field_position'])

      if params['integration_field_mapping']['field_position'].present? && query.take.present? && !( query.pluck(:id).include?(integration_field_mapping.id) && query.count == 1)
        flash[:error] = "Field Positions must be unique for each company."
        redirect_to(:action => :edit) and return
      end

      set_mapper_attributes
      integration_field_mapping.update(permit_params[:integration_field_mapping])
      redirect_to :action => :show
    end

    def create
      if params['integration_field_mapping']['company_id'].present? && Company.find_by(id: params['integration_field_mapping']['company_id']).integration_field_mappings.where(field_position: params['integration_field_mapping']['field_position']).present?
        flash[:error] = "Field Positions must be unique for each company."
        redirect_to(:action => :new) and return
      end

      current_admin_user.active_admin_loggings.create!(action: "Created Integration Field Mapping with Integration Field Key = #{params[:integration_field_mapping][:integration_field_key]}")

      set_mapper_attributes
      create!
    end

    def scoped_collection
      end_of_association_chain.all
    end

    def destroy
      current_admin_user.active_admin_loggings.create!(action: "Deleted Integration Field Mapping with id #{params[:id]}")
      destroy!
    end

    def new
      @page_title="Kallidus Learn Field Mapping"
      super
    end

    def set_mapper_attributes
      custom_field = params['integration_field_mapping']['custom_field_id'].numeric? ? CustomField.where('id = ? AND company_id = ?', params['integration_field_mapping']['custom_field_id'], params['integration_field_mapping']['company_id']).take : nil
      if custom_field.present?
        params['integration_field_mapping']['preference_field_id'] = nil
        params['integration_field_mapping']['is_custom'] = '1'
        params['integration_field_mapping']['parent_hash'] = 'customInformation'
        params['integration_field_mapping']['parent_hash_path'] = 'customInformation'
      else
        params['integration_field_mapping']['preference_field_id'] = params['integration_field_mapping']['custom_field_id']
        params['integration_field_mapping']['custom_field_id'] = nil
        params['integration_field_mapping']['is_custom'] = '0'
        if ['loc', 'dpt', 'pn'].include?(params['integration_field_mapping']['preference_field_id'])
          params['integration_field_mapping']['parent_hash'] = 'customInformation'
          params['integration_field_mapping']['parent_hash_path'] = 'customInformation'
        else
          params['integration_field_mapping']['parent_hash'] = nil
          params['integration_field_mapping']['parent_hash_path'] = nil
        end
      end
    end
  end

  order_by(:field_position) do |order_clause|
   [order_clause.to_sql, 'NULLS FIRST'].join(' ')
  end

  index do
    selectable_column
    id_column
    column :Company do |ifm|
      Company.find_by(id: ifm.company_id)
    end

    column :Integration_Instance do |ifm|
      IntegrationInstance.find_by(id: ifm.integration_instance_id)
    end

    column :Field_Name do |ifm|
      if ifm.is_custom?
        ifm.company.custom_fields.map {|field| field.name if field.id == ifm.custom_field_id }.compact.first
      else
        ifm.preference_field_id == 'email' ? 'Email' : ifm.company.prefrences['default_fields'].map {|field| field['name'] if field['id'] == ifm.preference_field_id}.compact.first
      end
    end
    column :Field_Mapping_Key do |ifm|
      ifm.integration_field_key
    end

    column :Field_Position, sortable: true do |ifm|
      ifm.field_position.to_i
    end
    
    actions
  end

  form html: {id: "integration_field_mapping_form", data: {parsley_validate: true}} do |f|
    f.inputs "Select the Fields to send from Sapling to Kallidus Learn; field position must match the configuration in Kallidus Manager." do
      field_mapping = IntegrationFieldMapping.find_by(id: params[:id])
      company = field_mapping.present? ? field_mapping.company : nil 
      
      if f.object.new_record?
        f.input :company_id, as: :select, id: :integration_field_mapping_company_id, :collection => Company.all_companies_alphabeticaly.pluck(:name, :id), input_html: {required: ''}
        f.input :integration_instance_id, as: :select, label: "Select Integration Instance To Map Field With", :collection => []
      else
        f.input :company_id, id: :integration_field_mapping_company_id, as: :hidden, :input_html => {value: company.id}
        f.input :integration_instance_id, as: :hidden, input_html: {value: field_mapping&.integration_instance_id}
      end
      f.input :custom_field_id, as: :select, label: "Field Name", :selected => field_mapping&.is_custom ? field_mapping&.custom_field_id : field_mapping&.preference_field_id, :collection => params[:id] ? company.custom_fields.pluck(:name, :id) + company.prefrences['default_fields'].map {|field| [field['name'], field['id']]}: [], input_html: {required: ''}

      f.input :integration_field_key, label: 'Field Mapping Key', input_html: {required: ''} #Integration Field Key Name (This is the key of Mapping Field)

      f.input :field_position, label: "Field Position", :input_html => {value: params[:id] ? IntegrationFieldMapping.find_by(id: params[:id]).field_position : nil , required: ''}
    end
    f.actions do
      f.action :submit, label: "SAVE"
    end
  end
end
