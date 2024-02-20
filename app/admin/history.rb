ActiveAdmin.register PaperTrail::Version, as: "Version" do

  menu label: "Versions", parent: "Loggings"

  filter :company_name, as: :select, :collection => proc { Company.all_companies_alphabeticaly }, label: "Company" rescue nil
  filter :item_type, label: "Database table"
  filter :item_id
  filter :event
  filter :whodunnit, label: "User ID"
  filter :created_at
  filter :ip

  index do
    selectable_column
    id_column
    column :item_id
    column "Company", :company_name
    column "Database table", :item_type
    column :event
    column "User ID", :whodunnit
    column :created_at
    column :ip
    actions
  end

  show do
    attributes_table do
      row :id
      row "Company" do |r|
        r.company_name
      end
      row "Database table" do |r|
        r.item_type
      end
      row :item_id
      row :event
      row "User ID" do |r|
        r.whodunnit
      end
      row "Changes" do |r|
        r.changeset
      end
      row :object
      row :created_at
      row :ip
      row :user_agent
    end
  end

  controller do
    def index
      current_admin_user.active_admin_loggings.create!(action: "View all Versions")
      histories = History.unscoped { super }
    end

    def show
      current_admin_user.active_admin_loggings.create!(action: "Viewed Version", version_id: params[:id])
      history = History.unscoped do
        super
        History.find_by(id: params[:id])
      end
      history
    end

    def destroy
      current_admin_user.active_admin_loggings.create!(action: "Deleted Version with id #{params[:id]}")
      destroy!
    end

  end

end
