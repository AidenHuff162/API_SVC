ActiveAdmin.register User do
  config.sort_order = 'id_asc'
  config.batch_actions = true
  JSON :partial => 'verify_password_strength'
  permit_params :title, :first_name, :last_name, :email, :personal_email, :onboard_email,
                :company_id, :team_id, :location_id, :role, :manager_id,
                :start_date, :state, :password, :password_confirmation,
                :uid, :provider, :buddy_id, :current_stage, :preferred_name, :guid,
                :is_gdpr_action_taken, :gdpr_action_date, :sent_to_bswift, :seen_profile_setup,
                :otp_required_for_login, :show_qr_code, :seen_documents_v2

  before_destroy :remove_from_algolia
  before_save do |user|
    user.updated_by_admin = true
  end

  before_action do
    User.class_eval do
      def to_param
        id.to_s
      end
    end
  end

  action_item :go_to_profile, only: :show do
    full_domain = user.company.app_domain
    link_to('Go to Profile',"https://#{full_domain}/#/profile/#{user.id}")
  end

  controller do
    def show
      user = User.unscoped do
        super
        User.find_by(id: params[:id])
      end

      if user
        user_obj = User.with_deleted.find_by(id: params[:id])
        if user_obj.present?
          action = "Viewed user"
          current_admin_user.active_admin_loggings.create!(action: action, user_id: user_obj.id)
        end
      end
      user
    end      
    
    def index
      if params[:restored].present? and params[:restored] == 'false'
        params.delete(:restored)
        flash[:alert] = "Restore failed! \n User email or Personal Email already in use for another user. To restore this user you have to change email or personal email of this user."
      end
      if session[:not_deleted].present? and session[:not_deleted] == 'true'
        session.delete(:not_deleted)
        flash[:alert] = "All Users cannot be Deleted"
      end
      current_admin_user.active_admin_loggings.create!(action: "Viewed all users")
      user = User.unscoped { super }
    end

    def scoped_collection
      end_of_association_chain
        .includes(:manager)
        .includes(:company)
        .where(companies: {deleted_at: nil})
    end

    def remove_from_algolia(user)
      AlgoliaWorker.perform_now(@user.id, nil, true)
    end

    def create
      params[:user][:uid] = Random.new_seed
      params[:user][:current_stage] = 'registered' if params[:user][:current_stage]  == 'active'
      current_admin_user.active_admin_loggings.create!(action: "Created a user with email = #{params[:user][:email]}")
      create!
    end

    def update
      params[:user][:uid] = params[:id]
      params[:user][:current_stage] = 'registered' if params[:user][:current_stage]  == 'active'
      current_admin_user.active_admin_loggings.create!(action: "Updated a user", user_id: params[:id])
      update!
    end

    def destroy
      if params && params[:id].present?
        user = User.unscoped.find_by_id(params[:id])
        if user
          begin
            user.really_destroy!
            current_admin_user.active_admin_loggings.create!(action: "Deleted a user with email #{user.email}")
          rescue Exception => e
            logger.info "Failed to delete the user with email #{user.email}"
            logger.info "Due to Error => #{e}"
            flash[:error] = "Failed to delete user #{user.email}"
          end
        end
        redirect_to collection_url
      end
    end
  end

  collection_action :verify_password_strength, format: :json do
    if params[:password].present?
      render json: { password_acceptable: StrongPassword::StrengthChecker.new(min_entropy: 10, min_word_length: 8, use_dictionary: true).is_strong?(params[:password]) }.as_json
    end
  end
  member_action :restore, method: :get do
    restored = true
    user_id = params[:id]
    restore_user = User.unscoped.find_by(id: user_id)
    if restore_user.allowed_to_restore?
      restore_user.update_column(:visibility, true)
      User.restore(user_id, recursive: true)
      User.find_by(id: user_id).update_column(:deletion_through_gdpr, false)
      current_admin_user.active_admin_loggings.create!(action: "Restored user", user_id: user_id)
    else
      restored = false
    end
    redirect_to admin_users_path({restored: restored})
  end

  filter :company,collection: Company.all_companies_alphabeticaly
  filter :first_name
  filter :last_name
  filter :email, label: "Company Email"
  filter :personal_email, label: "Personal Email"
  filter :role, as: :select, multiple: true, collection: User.roles
  filter :current_stage, as: :select, multiple: true, collection: User.current_stages.transform_keys { |h| h == 'registered' ? 'active' : h}
  filter :created_at
  filter :updated_at
  batch_action :destroy, confirm: "Are you sure?" do |ids|
    if params['collection_selection_toggle_all']!='on'
      ids.each do |id|
        ActiveAdmin::DestroyUser::DestroyUserAndAssoications.new(id).perform
      end
      current_admin_user.active_admin_loggings.create!(action: "Destroyed users with ids: #{ids}")
      redirect_to collection_path
    else
      session[:not_deleted]='true'
      redirect_to collection_path
    end
  end
  batch_action :send_invite_email do |ids|
    User.find(ids).each do |user|
      Interactions::Users::SendInvite.new(user.id).perform if !(user.departed? || user.incomplete?)
      current_admin_user.active_admin_loggings.create!(action: "Sent invitation to users with ids: #{ids}")
    end
    redirect_to collection_path
  end

  index do
    selectable_column
    id_column
    column :company
    column :guid
    column :first_name
    column :last_name
    column :role
    column :current_stage do |user|
      user.current_stage == 'registered' ? 'active' : user.current_stage
    end
    column "Current State",:state
    column :created_at
    actions defaults: true do |user|
      if user.paranoia_destroyed?
        link_to "Restore", restore_admin_user_path(user), method: :get
      end
    end
  end

  show do
    attributes_table do
      row :company
      row :uid
      row :first_name
      row :last_name
      row :email
      row :personal_email
      row :start_date
      row :role
      row :state
      row :sign_in_count
      row :current_stage do
        user.current_stage  == 'registered' ? 'active' : user.current_stage
      end
      row :"Pto Audit log" do
        link_to("Pto Audit log", admin_user_pto_balance_audit_logs_path(user.id))
      end
      row :termination_date
      row :is_gdpr_action_taken
      row :gdpr_action_date
      row :sent_to_bswift
      row :seen_profile_setup
      row :seen_documents_v2
      row 'Enable Two Factor Authentication' do
        user.otp_required_for_login
      end
      row 'Display QR Barcode' do
        user.show_qr_code
      end
      row :current_sign_in_at
      row :last_sign_in_at
      row :created_at
      row :updated_at
    end
    active_admin_comments
  end

  member_action :push_to_paylocity, method: :get do
    user = User.find(params[:id])
    HrisIntegrationsService::Paylocity::ManageSaplingProfileInPaylocity.new(user).perform("create")
    user.reload
    if user.paylocity_onboard
      flash[:notice] = "Successfully pushed to Paylocity!"
    else
      flash[:notice] = "Failed to push to Paylocity. Please check logs."
    end
    redirect_to admin_user_path
  end

  action_item :paylocity, only: :show, :if => proc { Company.find_by_id(user.company_id)&.integration_instances&.where(api_identifier: "paylocity")&.first&.state == 'active' && !user.paylocity_onboard && user.active? } do 
    link_to 'Push to Paylocity', push_to_paylocity_admin_user_path
  end

  form html: {id: "company", data: {parsley_validate: true} } do |f|
    f.semantic_errors *f.object.errors.keys
    f.inputs "User Details" do
      if f.object.new_record?
        f.input :company_id, as: :select, :collection => Company.all_companies_alphabeticaly.pluck(:name, :id), input_html: {required: ''}
      end
      f.input :first_name, input_html: {required: ''}
      f.input :last_name, input_html: {required: ''}
      f.input :title, input_html: {required: ''}
      f.input :start_date, input_html: {required: '', 'data-parsley-validate-date': ''}, as: :datepicker, datepicker_options: { min_date: "1980-01-1", max_date: "+10Y"}
      f.input :password
      
      div :class => 'show_password_head_one' 
      span "At least 8 characters", class: 'show_password_text_one'
      div :class => 'show_password_head_two' 
      span "One number", class: 'show_password_text_two'
      div :class => 'show_password_head_three' 
      span "One lowercase character", class: 'show_password_text_three'
      div :class => 'show_password_head_four' 
      span "One special character", class: 'show_password_text_four'
      div :class => 'show_password_head_five' 
      span "One uppercase character", class: 'show_password_text_five'
      div :class => 'show_password_head_six' 
      span "Not easily guessable", class: 'show_password_text_six'
      
      f.input :onboard_email
      if f.object.id
        f.input :email
      end
      if f.object.new_record?
        f.input :email, input_html: {required: ''}
      end
      f.input :personal_email

      f.input :role
      f.input :state, as: :select, :collection => ["active", "inactive"]
      f.input :provider, as: :hidden
      f.input :uid, as: :hidden
      f.input :current_stage, as: :select, collection: User.current_stages.keys.map { |w| [w == 'registered'? 'active' : w, w]}, label: 'Current Stage'
      f.input :is_gdpr_action_taken
      f.input :gdpr_action_date
      f.input :sent_to_bswift
      f.input :seen_profile_setup
      if f.object.id 
        if f.object.super_user || f.object.company.otp_required_for_login?
          f.input :otp_required_for_login, label: 'Enable Two Factor Authentication'
          f.input :show_qr_code, label: 'Display QR Barcode'
        end
      end
    end
    f.actions
  end
end
