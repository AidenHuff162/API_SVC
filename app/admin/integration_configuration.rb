ActiveAdmin.register IntegrationConfiguration, as: "Integration Configuration" do
  
  menu label: "Integration Configuration", parent: "Integration Management", priority: 1
  
  permit_params :category, :field_name, :field_type, :help_text, :is_required, :is_visible,
                :integration_inventory_id, :dropdown_options, :toggle_context, :toggle_identifier, :width,
                :vendor_domain, :position, :is_encrypted
  actions :all

  collection_action :get_toggle_identifiers, format: :json do
    inventories = IntegrationConfiguration.where(integration_inventory_id: params[:inventory_id], category: 'settings').pluck(:toggle_identifier)
    render json: inventories.as_json
  end
  
  controller do
    def index
      current_admin_user.active_admin_loggings.create!(action: "View all Integration Inventory")
      integration_inventories = IntegrationConfiguration.unscoped { super }
    end

    def show
      current_admin_user.active_admin_loggings.create!(action: "Viewed Integration Configuration with id #{params[:id]}")
      integration_inventory = IntegrationConfiguration.unscoped do
        super
        IntegrationConfiguration.find_by(id: params[:id])
      end
      integration_inventory
    end

    def update
      current_admin_user.active_admin_loggings.create!(action: "Updated Integration Configuration with id #{params[:id]}")
      update!
    end

    def create
      current_admin_user.active_admin_loggings.create!(action: "Created Integration Configuration with name = #{params[:integration_configuration][:name]}")
      create!
    end

    def scoped_collection
      end_of_association_chain.all
    end

    def destroy
      current_admin_user.active_admin_loggings.create!(action: "Deleted Integration Configuration with id #{params[:id]}")
      destroy!
    end
  end

  index do
    selectable_column
    id_column
    column :inventory_name do |config|
      config.integration_inventory.display_name
    end
    column :category
    column :field_name
    column :field_type
    column :position
    column :toggle_context
    column :toggle_identifier
    column :updated_at
    actions
  end

  show do |c|
    attributes_table do
      row :integration_inventory
      row :category
      row :field_name
      row :field_type
      row :position
      row :toggle_context
      row :toggle_identifier
      row :dropdown_options
      row :vendor_domain
      row :width
      row :help_text
      row :is_required
      row :is_visible
      row :is_encrypted
      row :created_at
      row :updated_at
    end
  end

  form html: {id: "integration_configuration_form", data: {parsley_validate: true} } do |f|
    f.inputs "Integration Configuration Details" do
      if f.object.new_record?
        f.input :integration_inventory_id, as: :select, :collection => IntegrationInventory.pluck(:display_name, :id), input_html: {required: ''}
      end
      f.input :category, as: :select, :collection => {'Credentials'=> 'credentials', 'Settings'=> 'settings'}
      f.input :field_name, input_html: {include_blank: true}
      f.input :field_type, as: :select, :collection => {'Text'=> 'text', 'Subdomain' => 'subdomain', 'Dropdown' => 'dropdown', 'API Key' => 'sapling_api_key', 'Company options' => 'options', 'Client ID' => 'client_id', 'Public API Key' => 'public_api_key', 'Multi-Select' => 'multi_select'}
      f.input :position, input_html: {required: ''}
      f.input :toggle_context, input_html: {include_blank: true}
      f.input :toggle_identifier, as: :select, label: 'Toggle identifier: (The toggle identifier will be decided by the appropriate developer because it affects the integration)', collection: ['Can Import Data', 'Can Export Updation', 'Enable Onboarding Templates', 'Enable International Templates', 'Enable Company Code', 'Enable Tax Type', 'Can Delete Profile', 'Can Invite Profile', 'Can Export New Profile']
      f.input :dropdown_options, as: :jsonb, input_html: {include_blank: true}, label: 'Dropdown options: (Please add the dropdown options in the following format e-g [{"label":"test","value":123},{"label":"test1","value":456}])'
      f.input :vendor_domain, input_html: {include_blank: true}
      f.input :width, as: :select, :collection => {'50 %'=> '50', '100 %'=> '100'}
      f.input :help_text, input_html: {include_blank: true}
      f.input :is_required, input_html: {include_blank: true}
      f.input :is_visible, input_html: {include_blank: true}
      f.input :is_encrypted, input_html: {include_blank: true}
    end
    f.actions
  end
end
