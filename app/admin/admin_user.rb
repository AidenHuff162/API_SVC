ActiveAdmin.register AdminUser do
  role_changeable
  permit_params :email, :password, :password_confirmation, :otp_required_for_login, :otp_attempt, :expiry_date, :state, :role

  filter :email
  filter :state
  filter :sign_in_count
  filter :current_sign_in_at
  filter :created_at

  index do
    selectable_column
    id_column
    column :email
    column :state
    column '2FA Status', :two_fa_status
    column :sign_in_count
    column :created_at
    column :expiry_date
    column :role
    actions
  end

  show do
    attributes_table do
      row :id
      row :email
      row :role
      row :state
      row :expiry_date
      row :sign_in_count
      row :current_sign_in_at
      row :last_sign_in_at
      row :current_sign_in_ip
      row :last_sign_in_ip
      row :created_at
      row :updated_at
    end
  end

  action_item :edit_two_factor, only: :show do
    link_to(
      "Setup 2FA",
      edit_two_factor_admin_admin_user_path(admin_user),
    )
  end

  member_action :edit_two_factor, method: :get do
    @admin_user = AdminUser.find(params[:id])
    render template: "admin/admin_users/edit_two_factor"
  end

  member_action :update_two_factor, method: :patch do
    @admin_user = AdminUser.find(params[:id])
    @admin_user.setup_two_factor(params[:admin_user][:otp_required_for_login])
    if @admin_user.save!
      flash[:notice] = "Successfully updated!"
      redirect_to action: "edit_two_factor"
    else
      flash[:notice] = "Some error occurred!"
      redirect_to action: "edit_two_factor"
    end
  end


  form html: {id: "company", data: {parsley_validate: true} } do |f|
    f.semantic_errors *f.object.errors.keys
    f.inputs "Admin Details" do
      f.input :email, input_html: {required: ''}
      f.input :state, as: :select, :collection => [ 'active', 'inactive' ]
      f.input :role, as: :select, collection: ActiveAdminRole.config.roles.map { |key, value| [key, key] }, selected: 'guest_user', include_blank: false
      f.input :expiry_date, as: :datepicker, datepicker_options: { min_date: Date.today }, input_html: {required: ''}
    end
    f.actions
  end

  controller do

    def create
      current_admin_user.active_admin_loggings.create!(action: "Created an admin user with email = #{params[:admin_user][:email]}")
      create!
    end

    def index
      current_admin_user.active_admin_loggings.create!(action: "View all Admin users")
      admin_users = AdminUser.unscoped { super }
    end

    def show
      current_admin_user.active_admin_loggings.create!(action: "Viewed Admin user with id = #{params[:id]}")
      admin_user = AdminUser.unscoped do 
        super
        AdminUser.find_by(id: params[:id])
      end
      admin_user
    end

    def update
      current_admin_user.active_admin_loggings.create!(action: "Updated Admin user with id = #{params[:id]}")
      update!
    end

    def destroy
      current_admin_user.active_admin_loggings.create!(action: "Deleted Admin user with id = #{params[:id]}")
      destroy!
    end

  end

end
