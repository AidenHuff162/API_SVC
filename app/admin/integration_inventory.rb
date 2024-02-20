ActiveAdmin.register IntegrationInventory, as: "Integration Inventory" do
  
  menu label: "Integration Inventory", parent: "Integration Management", priority: 0

  permit_params :display_name, :display_logo, :dialog_display_logo, :status, :category, :knowledge_base_url,
                :data_direction, :enable_filters, :enable_test_sync, :state, :api_identifier, :enable_multiple_instance,
                :position, :enable_authorization, :enable_connect, :field_mapping_option, :field_mapping_direction, :mapping_description

  actions :all

  collection_action :get_integations, format: :json do
    inventories = IntegrationInventory.where(category: params[:category]).pluck(:api_identifier)
    render json: inventories.as_json
  end
  
  controller do
    def index
      current_admin_user.active_admin_loggings.create!(action: "View all Integration Inventory")
      integration_inventories = IntegrationInventory.unscoped { super }
    end

    def show
      current_admin_user.active_admin_loggings.create!(action: "Viewed Integration Inventory with id #{params[:id]}")
      integration_inventory = IntegrationInventory.unscoped do
        super
        IntegrationInventory.find_by(id: params[:id])
      end
      integration_inventory
    end

    def edit
      current_admin_user.active_admin_loggings.create!(action: "Edit Integration Inventory with id #{params[:id]}")
      integration_inventory = IntegrationInventory.unscoped do
        super
        IntegrationInventory.find_by(id: params[:id])
      end
      integration_inventory
    end

    def update
      current_admin_user.active_admin_loggings.create!(action: "Updated Integration Inventory with id #{params[:id]}")
      integration_inventory = IntegrationInventory.find_by_id(params[:id])
      integration_inventory.update(permit_params[:integration_inventory].except(:display_logo, :dialog_display_logo))
      if params[:integration_inventory][:display_logo].present?
        integration_inventory.display_logo&.destroy
        UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: params[:integration_inventory][:display_logo], type: 'UploadedFile::DisplayLogoImage', original_filename: params[:integration_inventory][:display_logo].original_filename, position: nil) 
      end
      if params[:integration_inventory][:dialog_display_logo].present?
        integration_inventory.dialog_display_logo&.destroy
        UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: params[:integration_inventory][:dialog_display_logo], type: 'UploadedFile::DialogDisplayLogoImage', original_filename: params[:integration_inventory][:dialog_display_logo].original_filename, position: nil) 
      end
      redirect_to :action => :show
    end

    def create
      current_admin_user.active_admin_loggings.create!(action: "Created Integration Inventory with name = #{params[:integration_inventory][:name]}")
      integration_inventory = IntegrationInventory.create(permit_params[:integration_inventory].except(:display_logo, :dialog_display_logo))
      UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: params[:integration_inventory][:display_logo], type: 'UploadedFile::DisplayLogoImage', original_filename: params[:integration_inventory][:display_logo].original_filename, position: nil) if params[:integration_inventory][:display_logo].present?
      UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: params[:integration_inventory][:dialog_display_logo], type: 'UploadedFile::DialogDisplayLogoImage', original_filename: params[:integration_inventory][:dialog_display_logo].original_filename, position: nil) if params[:integration_inventory][:dialog_display_logo].present?
      redirect_to :action => :index
    end

    def scoped_collection
      end_of_association_chain.all
    end

    def destroy
      current_admin_user.active_admin_loggings.create!(action: "Deleted Integration Inventory with id #{params[:id]}")
      destroy!
    end

    def new
       @page_title="New Integration Setup"
       super
    end
  end

  index do
    selectable_column
    id_column
    column :display_name
    column :status
    column :category
    column :state
    column :knowledge_base_url
    column :data_direction
    column :api_identifier
    column :updated_at
    actions
  end

  show do |c|
    attributes_table :title => "Integration Details" do
      row "Vendor Name:" do |inventory|
        inventory.display_name
      end 
      row "Status in production:" do |inventory|
        inventory.status
      end 
      row :category
      row :knowledge_base_url
      row "Data Sync Direction:" do |inventory|
        inventory.data_direction
      end 
      row :enable_filters
      row :enable_test_sync
      row :enable_authorization
      row :enable_connect
      row :state
      row :position
      row :enable_multiple_instance
      row :api_identifier
      row "Logo on the table:" do |inventory|
        image_tag inventory.display_logo&.file_url unless inventory.display_logo&.file_url.blank?
      end
      row "Logo on the overlay:" do |inventory|
        image_tag inventory.dialog_display_logo&.file_url unless inventory.dialog_display_logo&.file_url.blank?
      end
      row :created_at
      row :updated_at
    end
  end

  form html: {id: "integration_inventory_form", data: {parsley_validate: true}} do |f|
    f.inputs "Integration Inventory Details" do
      f.input :display_name, label: 'Vendor Name (This name will displayed as part of the overlay title)', input_html: {required: ''}
      if f.object.display_logo&.file_url.blank?
        f.input :display_logo, as: :file, label: "Upload the vendor's logo for the table (PNG only)", class: 'input-labels', input_html: {required: ''}
      else
        f.input :display_logo, as: :file, label: "Upload the vendor's logo for the table (PNG only)", class: 'input-labels', hint: f.image_tag(f.object.display_logo&.file_url(:thumb))  
      end
      if f.object.dialog_display_logo&.file_url.blank?
        f.input :dialog_display_logo, as: :file, label: "Upload the vendor's logo for the overlay (PNG only. Note the logo will be resized and fitted to a circle container)", class: 'input-labels', input_html: {required: ''}
      else
        f.input :dialog_display_logo, as: :file, label: "Upload the vendor's logo for the overlay (PNG only. Note the logo will be resized and fitted to a circle container)", class: 'input-labels', hint: f.image_tag(f.object.dialog_display_logo&.file_url(:thumb)) 
      end
      f.input :status, as: :select, label: "Status in production", :collection => {'Pending'=>'pending', 'New'=>'latest', 'Live'=>'live', 'Improved'=>'improved', 'Deprecated'=>'deprecated'}
      f.input :category, as: :select, :collection => IntegrationInventory.categories.keys.map { |w| [w.humanize, w] }
      f.input :knowledge_base_url, input_html: {required: ''}
      f.input :data_direction, as: :select, label: 'Data Sync Direction', :collection => {'Sapling to Partner'=> 's2p', 'Partner to Sapling'=> 'p2s', 'Bidirectional'=>'bi'}
      f.input :enable_filters, label: 'Allow Filters'
      f.input :enable_test_sync, label: 'Allow Test Sync'
      f.input :state, as: :select, :collection => {'Active'=>'active', 'Inactive'=>'inactive'}
      f.input :enable_authorization, label: 'Allow Authorization'
      f.input :enable_connect, label: 'Allow connect before saving credentials'
      f.input :position
      if f.object.new_record?
        f.input :api_identifier, label: 'Api identifier: (The api identifier will be decided by the appropriate developer because it affects the integration)', input_html: {required: ''}
      else
        f.input :api_identifier, label: 'Api identifier: (The api identifier will be decided by the appropriate developer because it affects the integration)', input_html: {required: '', disabled: true}
        f.label :enable_api_name, class: 'input-labels button', id: 'enable_api_name'
      end
      f.input :enable_multiple_instance
      f.input :field_mapping_option, as: :select, label: "Mapping Fields", :collection => {'Custom Groups'=>'custom_groups', 'All'=>'all_fields', 'Integration Fields'=>'integration_fields'}
      f.input :field_mapping_direction, as: :select, label: "Custom Mapping Fields Sync", :collection => {'Sapling'=>'sapling_mapping', 'Partner'=>'integration_mapping', 'Both' => 'both'}
      f.input :mapping_description, input_html: {required: ''}
    end
    f.actions do
      if f.object.new_record?
        f.action :submit, label: "Create Integration"
      else
        f.action :submit, label: "Update Integration"
      end
      f.action :cancel, label: "Cancel"
    end
  end
end
