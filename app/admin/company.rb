ActiveAdmin.register Company do
  menu label: "Set up", parent: "Company", priority: 0
  config.batch_actions = false
  permit_params :name, :subdomain, :abbreviation, :brand_color, :bio, :hiring_type,
                :send_email_alerts, :time_zone, :hide_gallery, :owner, :department,
                :buddy, :company_value,:preboarding_complete_emails,
                :manager_emails, :buddy_emails, :login_type, :company_plan,
                :department_mapping_key, :location_mapping_key, :group_for_home, :new_pending_hire_emails,
                :company_about, :enable_gsuite_integration, :sender_name, :paylocity_sui_state, :new_manager_form_emails,
                :document_completion_emails, :organization_root_id, :adp_us_company_code, :enabled_calendar, :surveys_enabled,
                :enabled_time_off, :enabled_org_chart, :is_using_custom_table, :start_date_change_emails, :paylocity_integration_type, :error_notification_emails,
                :can_push_adp_custom_fields, :pull_all_workday_workers, :adp_can_company_code, :account_state, :account_type, :notifications_enabled,
                :otp_required_for_login, :enable_custom_table_approval_engine, adp_us_integration_attributes: [:id, :can_import_data], self_signed_attributes: [:cert, :private_key],
                adp_can_integration_attributes: [:id, :can_import_data]

  action_item :default_users, only: :show do
    link_to 'CREATE DEFAULT USERS', action: 'upload_demo_users'
  end

  action_item :upload_workday, only: :show do
    link_to 'Upload Workday CF', action: 'upload_workday_csv'
  end

  action_item :delete_users, only: :show do
    link_to 'Delete Users', action: 'delete_users'
  end

  if Rails.env == 'production'
    action_item :create_assets_prod, only: :show do
      link_to 'Create Assets', action: 'assets'
    end
  else
    action_item :create_assets, only: :show do
      link_to 'Create Assets', action: 'assets'
    end
  end

  action_item :download_docs, only: :show do
    link_to 'Download Docs', action: 'download_documents'
  end

  action_item :download_profile_pictures, only: :show do
    link_to 'Download Profile Pictures', action: 'download_profile_pictures'
  end

  action_item :sync_learn_data, :only => [:show], :if => proc { Company.find(params[:id]).integration_instances.find_by(api_identifier: "kallidus_learn") } do
    link_to 'Sync Learn Data', :action => 'sync_learn_data'
  end

  member_action :delete_users do
    Company.find_by(id: params[:id].to_i).users.destroy_all
    current_admin_user.active_admin_loggings.create!(action: "Deleted all users for Company id", company_id: params[:id])
    redirect_to :action => :show
  end

  member_action :upload_demo_users do
    Company.upload_demo_users(params)
    redirect_to :action => :show
  end

  member_action :upload_workday_csv do
    render "admin/workday_csv"
  end

  member_action :assets do
    @companies = Company.where.not(id: params['id'].to_i).order(:name).pluck(:name, :id)
    render "admin/assets"
  end

  member_action :demo_assets do
    render "admin/demo_assets"
  end

  member_action :download_documents do
    Company.download_all_documents(params[:id], current_admin_user.email)
    current_admin_user.active_admin_loggings.create!(action: "Downloaded all documents for Company", company_id: params[:id])
    render "admin/download_company_documents"
  end

  member_action :download_profile_pictures do
    Company.download_profile_pictures(params[:id], current_admin_user.email)
    current_admin_user.active_admin_loggings.create!(action: "Downloaded all profile pictures for Company", company_id: params[:id])
    render "admin/download_profile_pictures"
  end

  member_action :sync_learn_data do
    ::LearningDevelopmentIntegrations::Kallidus::BulkCreateKallidusUserFromSaplingJob.perform_async(params[:id])
    current_admin_user.active_admin_loggings.create!(action: "Synced Data to Learn for Company", company_id: params[:id])
    redirect_to :action => :show
  end

  member_action :import_workday_csv, :method => :post do
    Company.upload_workday_fields(params[:id].to_i, params[:dump][:file])
    current_admin_user.active_admin_loggings.create!(action: "Uploaded workday custom field for Company", company_id: params[:id])
    redirect_to :action => :show
  end

  member_action :create_assets, :method => :post do
    Company.create_assets(params)
    current_admin_user.active_admin_loggings.create!(action: "Created assets for Company", company_id: params[:id])
    redirect_to :action => :show
  end

  member_action :create_demo_assets, :method => :post do
    params['email'] = current_admin_user.email
    Company.create_assets(params)
    current_admin_user.active_admin_loggings.create!(action: "Created demo assets for tenant", company_id: params[:id])
    redirect_to :action => :show
  end

  member_action :domain_renderer do
    render "admin/domain", locals: { flag: false }
  end

  member_action :remove_company, :method => :post do
    company = Company.find(params[:id].to_i)
    if params[:company_domain][:domain] == company.domain
      company.destroy_by_job
      current_admin_user.active_admin_loggings.create!(action: "Deleted Company with id = #{company.id}")
      redirect_to action: "index"
    else
      render "admin/domain", locals: { flag: true }
    end
  end

  member_action :reactivate, method: :get do
    company_id = params[:id]
    company = Company.find_by(id: company_id)

    if company.present? && company.inactive?
      company.update_columns(account_state: 'active')
      current_admin_user.active_admin_loggings.create!(action: "Reactivated Company", company_id: params[:id])
    end
    redirect_to admin_companies_path
  end

  member_action :deactivate, method: :get do
    company_id = params[:id]
    company = Company.find_by(id: company_id)

    if company.present? && company.active?
      company.update_columns(account_state: 'inactive')
      current_admin_user.active_admin_loggings.create!(action: "Deactivated Company", company_id: params[:id])
    end
    redirect_to admin_companies_path
  end

  controller do
    def index
      current_admin_user.active_admin_loggings.create!(action: "View all Companies")
      companies = Company.unscoped { super }
    end

    def show
      current_admin_user.active_admin_loggings.create!(action: "Viewed Company", company_id: params[:id])
      company = Company.unscoped do
        super
        Company.find_by(id: params[:id])
      end
      company
    end

    def update
      trial_end_date = params.dig(:trial_end_date, :company, :trial_end_date)
      current_admin_user.active_admin_loggings.create!(action: "Updated Company", company_id: params[:id])
      if check_subdomain
        update_billing(trial_end_date) if trial_end_date
        update!
      else
        flash[:notice] = "Subdomain already exists"
        redirect_to edit_admin_company_path
      end
    end
    

    def create
      current_admin_user.active_admin_loggings.create!(action: "Created Company with name = #{params[:company][:name]}")
      if check_subdomain
        create!
      else
        flash[:error] = "Subdomain already exists"
        redirect_to new_admin_company_path
      end
    end

    def scoped_collection
      end_of_association_chain.where(deleted_at: nil).includes(:organization_root)
    end

    def destroy
      redirect_to action: :domain_renderer
    end

    def new
      @page_title="Create New Company"
      super
    end

    private
    def check_subdomain
      params_subdomain = params[:company][:subdomain]
      companies = Company.unscoped.all
      subdomains = companies.select(:id, :subdomain)
      if params[:id]
        return true if subdomains.where(id: params[:id], subdomain: params_subdomain).present?
      end
      subdomains.find_by_subdomain(params_subdomain).blank?
    end

    def update_billing trial_end_date
      company = Company.find_by(id: params[:id])
      company.billing&.update(trial_end_date: trial_end_date) if company
    end
  end

  filter :name
  filter :subdomain
  filter :account_type, as: :select, multiple: true, collection: Company.account_types
  filter :created_at
  filter :updated_at

  index do
    selectable_column
    id_column
    column :name
    column :subdomain
    column :account_state
    column :account_type
    column :users_count
    column :hiring_type
    column :created_at
    column :updated_at
    actions

    actions defaults: false do |company|
      if company.active?
        link_to "Deactivate", deactivate_admin_company_path(company), method: :get, data: {confirm: 'Are you sure you want to deactivate account?'}
      else
        link_to "Reactivate", reactivate_admin_company_path(company), method: :get, data: {confirm: 'Are you sure you want to reactivate account?'}
      end
    end
  end

  show do |c|
    attributes_table do
      row :id
      row :name
      row :subdomain
      row :account_state
      row :account_type
      row :users_count
      row :created_at
      row :updated_at
      row :login_type
      if c.billing.present?
        row I18n.t 'active_admin.company.trial_end_date' do
          c.billing.trial_end_date
        end
      end
      row I18n.t 'active_admin.company.is_using_custom_table' do
        c.is_using_custom_table
      end
      row I18n.t 'active_admin.company.otp_required_for_login' do
        c.otp_required_for_login
      end
      row I18n.t 'active_admin.company.notifications_enabled' do
        c.notifications_enabled
      end
      row I18n.t 'active_admin.company.buddy' do
        c.buddy
      end
      row I18n.t 'active_admin.company.group_for_home' do
        c.group_for_home
      end
      row :department_mapping_key
      row :location_mapping_key
      row I18n.t 'active_admin.company.can_push_adp_custom_fields' do
        c.can_push_adp_custom_fields
      end
      row I18n.t 'active_admin.company.pull_all_workday_workers' do
        c.pull_all_workday_workers
      end
      row I18n.t 'active_admin.company.error_notification_emails' do
        c.error_notification_emails.join(", ")
      end
      row I18n.t 'active_admin.company.enabled_calendar' do
        c.enabled_calendar
      end
      row I18n.t 'active_admin.company.surveys_enabled' do
        c.surveys_enabled
      end
      row I18n.t 'active_admin.company.enabled_time_off' do
        c.enabled_time_off
      end
      row I18n.t 'active_admin.company.enabled_org_chart' do
        c.enabled_org_chart
      end
      row I18n.t 'active_admin.company.enable_custom_table_approval_engine' do
        c.enable_custom_table_approval_engine
      end
      row I18n.t 'active_admin.company.company_plans' do
        c.company_plan.titleize
      end
    end
  end

  form html: {id: "company_form", data: {parsley_validate: true} } do |f|
    render partial: 'form'                        
  end
end
