class IntegrationInstance < ApplicationRecord
  attr_accessor :skip_callback
  include IntegrationParamMapperOperations
  has_paper_trail
  acts_as_paranoid
  
  belongs_to :company
  belongs_to :integration_inventory
  has_many :integration_credentials
  has_many :integration_field_mappings, dependent: :destroy
  has_many :field_histories, dependent: :nullify

  has_many :visible_integration_credentials, -> (object) { joins(:integration_configuration).where(integration_configurations: {is_visible: true}).order("integration_configurations.position ASC") }, class_name: 'IntegrationCredential', foreign_key: :integration_instance_id
  belongs_to :connected_by, class_name: 'User'

  accepts_nested_attributes_for :integration_credentials, allow_destroy: true
  accepts_nested_attributes_for :integration_field_mappings, allow_destroy: true

  validates_with FiltersUniquenessValidator, if: Proc.new { |instance| instance.integration_inventory.enable_filters? && bypass_lde_filters_validation_for_digitalocean(instance) }
  validates_with MultiInstanceValidator, on: :create

  scope :by_inventory, -> (inventory_id, company_id) { where(company_id: company_id, integration_inventory_id: inventory_id).order(id: :asc) }
  scope :fetch_exisiting_filters, -> (id, company_id, category){ joins(:integration_inventory).where.not(id: id).where('integration_inventories.category = ? AND integration_instances.company_id = ? AND integration_instances.state = 1 AND integration_inventories.enable_filters = true', IntegrationInventory.categories[category], company_id) }
  scope :enabled, -> { where("api_identifier IS NOT NULL AND state = #{IntegrationInstance.states['active']}")  }
  after_create :update_sapling_with_one_login, if: Proc.new { |integration| integration.api_identifier == 'one_login' && integration.client_id.present? && integration.client_secret.present? && integration.region.present? }
  after_create :sync_okta_users, if: Proc.new { |integration| integration.api_identifier == 'okta' }
  before_destroy :disable_sso, if: Proc.new { |integration| integration.company.present? && ['active_directory_federation_services', 'okta', 'one_login', 'ping_id'].include?(integration.api_identifier) }
  after_update :disable_sso, if: Proc.new { |integration| integration.company.present? && integration.api_identifier == 'google_auth' && !integration.active? }
  after_create :disable_create_profile, if: Proc.new { |integration| ['okta', 'one_login', 'ping_id'].include?(integration.api_identifier) }
  
  after_create :create_invisible_fields_credentials
  after_create :ensure_unique_auth, if: Proc.new { |integration| ['google_auth', 'shibboleth', 'active_directory_federation_services', 'okta', 'one_login', 'ping_id'].include?(integration.api_identifier) && integration.company_id.present? }
  after_create { create_integration_field_mappings if self.integration_inventory.present? && self.api_identifier == 'kallidus_learn'}
  after_create { manage_payroll_integration_change if self.active? && self.skip_callback.blank? }
  after_update { manage_payroll_integration_change if self.active? && self.saved_change_to_state? }
  after_update { manage_company_code_field if self.active? && ['adp_wfn_us', 'adp_wfn_can'].include?(self.api_identifier) && self.enable_company_code }
  after_update :filter_change_operations, if: :execute_filter_change_operations?
  after_create :ensure_unique_provision, if: Proc.new { |integration| ['gsuite', 'adfs_productivity'].include?(integration.api_identifier) && integration.company_id.present? }

  before_destroy :remove_partner_connection, if: :active?
  before_destroy :unauth_gsuite_account, if: Proc.new { |c| c.api_identifier == 'gsuite' }
  after_update :create_gsuite_fields, if: Proc.new { |integration| integration.api_identifier == 'gsuite' && integration.company.google_groups_feature_flag.present? && integration.gsuite_auth_credentials_present.present? }
  after_rollback :log_asana_errors, if: Proc.new { |integration| integration.api_identifier == 'asana' }
  before_create :validate_credentials, if: Proc.new { |integration| integration.api_identifier == 'asana' && integration.company.present? }
  before_destroy :remove_dependencies
  
  enum state: { inactive: 0, active: 1 }
  enum sync_status: { succeed: 0, in_progress: 1, failed: 2, error: 3 }

  #Configurations
  def subdomain(value=nil); manage_credentials(__method__, value) end
  def username(value=nil); manage_credentials(__method__, value) end
  def password(value=nil); manage_credentials(__method__, value) end
  def api_key(value=nil); manage_credentials(__method__, value) end
  def region(value=nil); manage_credentials(__method__, value) end
  def client_id(value=nil); manage_credentials(__method__, value) end
  def client_secret(value=nil); manage_credentials(__method__, value) end
  def access_token(value=nil); manage_credentials(__method__, value) end
  def secret_token(value=nil); manage_credentials(__method__, value) end
  def refresh_token(value=nil); manage_credentials(__method__, value) end
  def expires_in(value=nil); manage_credentials(__method__, value) end
  def company_code(value=nil); manage_credentials(__method__, value) end
  def environment(value=nil); manage_credentials(__method__, value) end
  def organization_name(value=nil); manage_credentials(__method__, value) end
  def subscription_id(value=nil); manage_credentials(__method__, value) end
  def payroll_calendar(value=nil); manage_credentials(__method__, value) end
  def employee_group(value=nil); manage_credentials(__method__, value) end
  def pay_template(value=nil); manage_credentials(__method__, value) end
  def integration_type(value=nil); manage_credentials(__method__, value) end
  def sui_state(value=nil); manage_credentials(__method__, value) end
  def storage_folder_path(value=nil); manage_credentials(__method__, value) end
  def storage_account_name(value=nil); manage_credentials(__method__, value) end
  def storage_access_key(value=nil); manage_credentials(__method__, value) end
  def signature_token(value=nil); manage_credentials(__method__, value) end
  def company_url(value=nil); manage_credentials(__method__, value) end
  def permanent_access_token(value=nil); manage_credentials(__method__, value) end
  def private_api_key(value=nil); manage_credentials(__method__, value) end
  def domain(value=nil); manage_credentials(__method__, value) end
  def bswift_remote_path(value=nil); manage_credentials(__method__, value) end
  def bswift_hostname(value=nil); manage_credentials(__method__, value) end
  def bswift_username(value=nil); manage_credentials(__method__, value) end
  def bswift_password(value=nil); manage_credentials(__method__, value) end
  def bswift_group_number(value=nil); manage_credentials(__method__, value) end
  def bswift_relation(value=nil); manage_credentials(__method__, value) end
  def hiring_context(value=nil); manage_credentials(__method__, value) end
  def asana_organization_id(value=nil); manage_credentials(__method__, value) end
  def asana_default_team(value=nil); manage_credentials(__method__, value) end
  def asana_personal_token(value=nil); manage_credentials(__method__, value) end
  def identity_provider_sso_url(value=nil); manage_credentials(__method__, value) end
  def saml_certificate(value=nil); manage_credentials(__method__, value) end
  def saml_metadata_endpoint(value=nil); manage_credentials(__method__, value) end
  def gsuite_account_url(value=nil); manage_credentials(__method__, value) end
  def webhook_url(value=nil); manage_credentials(__method__, value) end
  def channel(value=nil); manage_credentials(__method__, value) end

  #Settings
  def can_invite_profile; fetch_setting_value(__method__) end
  def can_delete_profile; fetch_setting_value(__method__) end
  def can_export_new_profile; fetch_setting_value(__method__) end
  def can_update_profile; fetch_setting_value(__method__) end
  def bswift_auto_enroll; fetch_setting_value(__method__) end
  def enable_company_code; fetch_setting_value(__method__) end
  def can_import_data; fetch_setting_value(__method__) end
  def enable_tax_type; fetch_setting_value(__method__) end
  def enable_create_profile; fetch_setting_value(__method__) end
  def enable_update_profile; fetch_setting_value(__method__) end
  def can_export_updation; fetch_setting_value(__method__) end
  def sync_preferred_name; fetch_setting_value(__method__) end
  def link_gsuite_personal_email; fetch_setting_value(__method__) end
  def gsuite_auth_credentials_present; fetch_setting_value(__method__) end

  #General
  def callback_url(user_id, request_host=nil)
    get_instance_based_callback_url(user_id, request_host)
  end

  def self.generate_client_credentials(company, type)
    credentials = case type
                  when 'client_id'
                    client_id = JsonWebToken.encode({company_id: company.id, company_domain: company.domain, Time: Time.now.to_i})
                    ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base).encrypt_and_sign(client_id)
                  when 'public_api_key'
                    "#{SecureRandom.hex(15)}#{company.id}#{Time.now.to_i}"
                  end
    credentials
  end

  def unsync_users
    return User.none if inactive?

    not_incomplete_users = company.users.not_incomplete
    if api_identifier == 'workday'
      workday_filtered_users = IntegrationsService::Filters.call(not_incomplete_users.with_workday, self)
      not_incomplete_users.where('id NOT IN (?) AND super_user = FALSE', workday_filtered_users.ids)
    else
      User.none
    end
  end

  private

  def manage_credentials(method_name, value)
    return unless method_name.present?

    method_name = method_name.to_s.gsub('_', ' ').downcase.strip

    value.present? ? assign_credential_value(method_name, value) : fetch_credential_value(method_name)
  end

  def fetch_setting_value(method_name)
    manage_credentials(method_name, nil) == 'true'
  end

  def fetch_credential_value(method_name)
  	Rails.cache.fetch("#{id}/integration_instance_#{method_name}", expires_in: 1.weeks) do
  		integration_credentials.by_name(method_name).take&.value
  	end
  end

  def assign_credential_value(method_name, value)
    credential = integration_credentials.by_name(method_name).take
    credential.update(value: value) if credential.present?
  end

  def get_instance_based_callback_url(user_id=nil, request_host=nil)
    case api_identifier
    when 'deputy'
      HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).authentication_request_url
    when 'gusto'
      HrisIntegrationsService::Gusto::AuthenticateApplication.new(company, id, user_id).authentication_request_url
    when 'xero'
      HrisIntegrationsService::Xero::InitializeApplication.new(company, {}, id, user_id).prepare_authetication_url
    when 'smart_recruiters'
      AtsIntegrationsService::SmartRecruiter::AuthorizeApplication.new(company).authentication_request_url
    when 'adfs_productivity'
      SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).authentication_request_url
    when 'gsuite'
      SsoIntegrationsService::Gsuite::AuthenticateApplication.new(company, request_host).prepare_authentication_url
    end
  end

  def create_invisible_fields_credentials

    integration_inventory.invisible_integration_configurations.find_each do |configuration|
      field_name = configuration.credentials? ? configuration.field_name : configuration.toggle_identifier
      integration_credentials.find_or_create_by(name: field_name, integration_configuration_id: configuration.id)
    end
  end

  def manage_payroll_integration_change
    Integrations::PayrollIntegrationChange.perform_async(company.id, api_identifier)
  end

  def remove_partner_connection
    case api_identifier
    when 'xero'
      ::HrisIntegrations::Xero::RemoveXeroConnection.new.perform(company.id, refresh_token, subscription_id)
    when 'asana'
      TaskUserConnection.joins(task: :workstream).where(workstreams: {company_id: self.company.id}).update_all(asana_id: nil) if self.company.present?
    end
  end

  def remove_dependencies
    self.integration_credentials.destroy_all
  end

  def filter_change_operations
    HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob.perform_async(company_id, true)
  end

  def execute_filter_change_operations?
    active? && api_identifier == 'workday' && saved_change_to_filters?
  end

  def validate_credentials
    result = AsanaService::MockCall.new(self).perform
    unless result == true
      self.errors.add(:base, message: result.to_s)
      return false
    end
    true
  end

  def log_asana_errors
    LoggingService::IntegrationLogging.new.create(self.company, 'Asana', 'Configuration', nil, self.errors.to_json, 500) unless Rails.env == 'test'
  end

  def ensure_unique_auth
    integrations_to_disable = ['google_auth', 'shibboleth', 'active_directory_federation_services', 'okta', 'one_login', 'ping_id']
    integrations_to_disable.delete(self.api_identifier)
    company = self.company
    login_type = company.login_type
    company.integration_instances.where(api_identifier: integrations_to_disable).destroy_all
    company.login_type = login_type
    company.save!
  end

  def disable_sso
    company = self.company
    company.login_type = "only_password"
    company.save!
  end

  def disable_create_profile
    self.integration_credentials.find_by(name: 'Enable Create Profile')&.update(value: false)
  end

  def update_sapling_with_one_login
    ::SsoIntegrations::OneLogin::UpdateSaplingUserFromOneloginJob.perform_async(self.company.id)
  end

  def sync_okta_users
    ::Okta::SyncOktaEmployeesJob.perform_async(self.id)
  end

  def ensure_unique_provision
    integrations_to_disable = ['gsuite', 'adfs_productivity']
    integrations_to_disable.delete(self.api_identifier)
    company = self.company
    company.integration_instances.where(api_identifier: integrations_to_disable).destroy_all
  end

  def unauth_gsuite_account
    begin
      company_id = self.company_id
      auth_lib_obj = Gsuite::GoogleApiAuthorizer.new
      authorizer = auth_lib_obj.get_authorizer(self.company)
      if authorizer.get_credentials_from_relation(self.company, company_id.to_i).present?
        authorizer.revoke_authorization_from_relation(self.company, self.company.id.to_i)
      end
    rescue Exception => e
      log(self.company, "Gsuite", "Unauthorize Gsuite Account", nil, {error: e.message}, 500)
    end
  end

  def create_gsuite_fields
    ::SsoIntegrations::Gsuite::MapOuAndGroupsFieldJob.perform_async(self.company_id)
  end

  def manage_company_code_field
    return if self.company.custom_fields.find_by(name: 'ADP Company Code')
    IntegrationsService::AdpWorkforceNow.new(self.company).manage_company_codes_custom_field(self)
  end

  def log(company, integration_name, action, request = nil, response = {}, status= nil)
    logging = LoggingService::IntegrationLogging.new
    logging.create(company, integration_name, action, request, response, status)
  end

  def bypass_lde_filters_validation_for_digitalocean(instance)
    if instance&.company&.subdomain == 'digitalocean'
      instance.integration_inventory.category != 'payroll_or_hr' ? true : false
    else
      return true
    end
  end
end