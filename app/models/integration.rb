require 'gsuite/google_api_authorizer'

class Integration < ApplicationRecord
  has_paper_trail
  belongs_to :company
  has_many :loggings, dependent: :nullify
  has_many :field_histories
  mount_uploader :public_key_file, FileUploader
  mount_uploader :private_key_file, FileUploader
  before_destroy :unauth_gsuite_account, if: Proc.new { |c| c.api_name == 'gsuite' }

  PROVISIONING_TYPES = ['gsuite', 'adfs_productivity']

  attr_accessor :skip_callback, :environment

  before_destroy :disable_sso, if: Proc.new { |integration| integration.company.present? && (integration.api_name == 'one_login' || integration.api_name == 'okta' || integration.api_name == 'active_directory_federation_services' || integration.api_name == 'ping_id') }
  after_save :update_sapling_groups_from_bamboo, if: Proc.new { |integration| (integration.company && integration.api_name.eql?('bamboo_hr') && (integration.company.integration_type == 'bamboo' || integration.company.integration_type == 'adp_wfn_profile_creation_and_bamboo_two_way_sync') && integration.api_key.present? && integration.subdomain.present? && (integration.saved_change_to_api_key? || integration.saved_change_to_subdomain?)) }
  after_update :disable_sso, if: Proc.new { |integration| integration.company.present? && integration.api_name == 'google_auth' && !integration.is_enabled }
  after_update :clear_jira_integration, if: Proc.new { |integration| integration.saved_change_to_channel? && integration.api_name == 'jira' && !@skip_callback}
  after_create :disable_create_profile, if: Proc.new { |integration| integration.api_name == 'one_login' || integration.api_name == 'okta' || integration.api_name == 'ping_id' }
  before_create :configure_asana, if: Proc.new { |integration| integration.api_name == 'asana' && integration.company.present? }
  after_commit :clear_cache, if: Proc.new { |integration| ['jira', 'gsuite', 'active_directory_federation_services'].include?(integration.api_name) }
  after_create :ensure_unique_payroll, if: Proc.new { |integration| ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'paylocity', 'xero', 'paychex', 'trinet', 'workday'].include?(integration.api_name) && integration.company_id.present? }
  after_create :ensure_unique_auth, if: Proc.new { |integration| ['google_auth', 'shibboleth', 'active_directory_federation_services', 'okta', 'one_login', 'ping_id'].include?(integration.api_name) && integration.company_id.present? }
  after_create :ensure_unique_provision, if: Proc.new { |integration| PROVISIONING_TYPES.include?(integration.api_name) && integration.company_id.present? }
  after_update :clear_auth_cache, if: Proc.new { |integration| integration.api_name == 'google_auth' && integration.company.present? }
  before_destroy :clear_auth_cache, if: Proc.new { |integration| ['google_auth', 'shibboleth', 'active_directory_federation_services', 'okta', 'one_login', 'ping_id'].include?(integration.api_name) && integration.company_id.present? }
  before_destroy :clear_provision_cache, if: Proc.new { |integration| PROVISIONING_TYPES.include?(integration.api_name) && integration.company_id.present?  }
  before_destroy :clear_asana_ids, if: Proc.new { |integration| integration.api_name == 'asana' && integration.company.present? }
  after_rollback :log_asana_errors, if: Proc.new { |integration| integration.api_name == 'asana' }
  after_destroy :clear_payroll_cache, if: Proc.new { |integration| ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'paylocity', 'xero', 'paychex', 'trinet'].include?(integration.api_name) && integration.company_id.present? }
  after_destroy :manage_payroll_integration_change, if: Proc.new { |integration| ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'paylocity'].include?(integration.api_name) && integration.company_id.present? }
  after_destroy :disable_on_linkedin, if: Proc.new { |integration| integration.api_name == 'linked_in' && integration.hiring_context.present? && integration.company_id.present? }
  after_create :update_sapling_option_mappings_from_adp, if: Proc.new { |integration| (integration.company && ['adp_wfn_us', 'adp_wfn_can'].include?(integration.api_name) && integration.client_id.present? && integration.client_secret.present?) }
  after_save :update_adp_onboarding_templates, if: Proc.new { |integration| (integration.company && ['adp_wfn_us', 'adp_wfn_can'].include?(integration.api_name) && integration.client_id.present? && integration.client_secret.present? &&
    ((integration.enable_onboarding_templates_before_last_save.blank? && integration.enable_onboarding_templates.present?) || (integration.enable_international_templates_before_last_save.blank? && integration.enable_international_templates.present?))) }
  after_commit :manage_company_codes_custom_field, on: [:create, :update], if: Proc.new { |integration| ['adp_wfn_us', 'adp_wfn_can'].include?(integration.api_name) && integration.saved_change_to_enable_company_code && integration.enable_company_code? } 
  after_commit :manage_tax_types_custom_field, on: [:create, :update], if: Proc.new { |integration| ['adp_wfn_us', 'adp_wfn_can'].include?(integration.api_name) && integration.saved_change_to_enable_tax_type && integration.enable_tax_type? } 

  after_save :manage_worked_in_country_custom_field, if: Proc.new { |integration| ['adp_wfn_us', 'adp_wfn_can'].include?(integration.api_name) && (integration.enable_international_templates_before_last_save.blank? && integration.enable_international_templates.present? && !integration.company.adp_v2_migration_feature_flag)} 
  after_save :manage_worked_in_country_custom_field, if: Proc.new { |integration| ['adp_wfn_us', 'adp_wfn_can'].include?(integration.api_name) && integration.company.adp_v2_migration_feature_flag}
  after_save :manage_sin_expiry_date_custom_field, if: Proc.new { |integration| ['adp_wfn_can'].include?(integration.api_name) && (integration.enable_international_templates_before_last_save.blank? && integration.enable_international_templates.present?)}

  after_save :update_sapling_with_learn_upon, if: Proc.new { |integration| integration.api_name == 'learn_upon' && integration.iusername.present? && integration.ipassword.present? && integration.subdomain.present? }
  after_save :update_sapling_with_lessonly, if: Proc.new { |integration| integration.api_name == 'lessonly' && integration.subdomain.present? && integration.api_key.present? }
  after_create :update_sapling_with_one_login, if: Proc.new { |integration| integration.api_name == 'one_login' && integration.client_id.present? && integration.client_secret.present? && integration.region.present? }
  after_create :create_trinet_preference_field, if: Proc.new { |integration| integration.api_name == 'trinet' && integration.client_id.present? && integration.client_secret.present? && integration.company_code.present? }
  after_destroy :delete_trinet_preference_field, if: Proc.new { |integration| integration.api_name == 'trinet' && integration.client_id.present? && integration.client_secret.present? && integration.company_code.present? }
  after_update :create_gsuite_fields, if: Proc.new { |integration| integration.api_name == 'gsuite' && integration.company.google_groups_feature_flag.present? && integration.saved_change_to_gsuite_auth_credentials_present && integration.gsuite_auth_credentials_present.present? }
  before_destroy :remove_xero_connections, if: Proc.new { |integration| integration.api_name == 'xero' && integration.subscription_id.present? && integration.company_code.present? && integration.access_token.present?}
  after_create :sync_okta_users, if: Proc.new { |integration| integration.api_name == 'okta' }


  attr_encrypted_options.merge!(:encode => true)
  attr_encrypted :api_key, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :secret_token, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :signature_token, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :access_token, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :slack_bot_access_token, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :refresh_token, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :client_secret, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :client_id, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :saml_certificate, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :iusername, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :ipassword, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :request_token, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  attr_encrypted :request_secret, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']

  validates_uniqueness_of :hiring_context, if: Proc.new {|integration| integration.api_name == 'linked_in' && integration.hiring_context != nil }

  scope :enabled, ->(exclude_integrations) { where.not(api_name: exclude_integrations)  }

  ADP_CUSTOM_FIELDS = [
    'Social Security Number',
    'Race/Ethnicity',
    'Gender',
    'Home Address',
    'Date of Birth',
    'Federal Marital Status',
    'Mobile Phone Number',
    'Home Phone Number'
  ]

  UPDATE_RESTRICTED_BAMBOO_FIELDS = [
    'Home Address',
    'Emergency Contact Name',
    'Date of Birth',
    'Social Security Number',
    'Gender',
    'Race/Ethnicity',
    'Federal Marital Status',
    'Emergency Contact Number',
    'Emergency Contact Relationship'
  ].freeze

 OKTA_CUSTOM_FIELDS = [
    'Mobile Phone Number',
    'Home Phone Number',
    'Employment Status',
    'Department',
    'Division',
    'Home Address'
  ].freeze

  def self.okta_custom_fields company_id
    custom_fields = OKTA_CUSTOM_FIELDS
    if company_id == 53
      custom_fields = custom_fields + ['Paylocity EE Number', 'Role Profile', 'Manager Role']
    end
    custom_fields
  end

  def self.paylocity
    find_by(company_id: nil, api_name: 'paylocity')
  end

  def update_sapling_groups_from_bamboo
    ::HrisIntegrations::Bamboo::UpdateSaplingGroupsFromBambooJob.perform_later(self.company)
  end

  def clear_jira_integration
    system "openssl genrsa -out private_key.pem 1024"
    system "openssl rsa -in private_key.pem -pubout -out public_key.pub"
    private_key_file = File.open "private_key.pem"
    public_key_file = File.open "public_key.pub"

    @skip_callback = true
    self.secret_token = nil
    self.client_secret = nil
    self.client_id = SecureRandom.urlsafe_base64(nil, false)
    self.private_key_file = private_key_file
    self.public_key_file = public_key_file
    self.jira_issue_statuses = []
    self.save!
  end

  def unauth_gsuite_account
    begin
      company_id = self.company_id
      auth_lib_obj = Gsuite::GoogleApiAuthorizer.new
      authorizer = auth_lib_obj.get_authorizer(company)
      if authorizer.get_credentials_from_relation(self.company, company_id.to_i).present?
        authorizer.revoke_authorization_from_relation(self.company, self.company.id.to_i)
      end
    rescue Exception => e
      log(company, "Gsuite", "Unauthorize Gsuite Account", nil, {error: e.message}, 500)
    end
  end

  def disable_create_profile
    self.update(enable_create_profile: false)
  end

  def disable_sso
    company = self.company
    company.login_type = "only_password"
    company.save!
  end

  def ensure_unique_payroll
    Rails.cache.delete("#{self.company_id}/integration_type")
    integrations_to_remove = ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'paylocity', 'workday', 'xero', 'paychex', 'trinet']
    integrations_to_remove.delete(self.api_name)
    if self.api_name == 'bamboo_hr'
      integrations_to_remove.delete('adp_wfn_us')
      integrations_to_remove.delete('adp_wfn_can')
    end
    if ['adp_wfn_us', 'adp_wfn_can'].include?(self.api_name)
      integrations_to_remove.delete('bamboo_hr')
      integrations_to_remove.delete('adp_wfn_us')
      integrations_to_remove.delete('adp_wfn_can')
    end
    company = self.company
    company.integrations.where(api_name: integrations_to_remove).destroy_all
    # update groups from integration
    company.update_groups_from_integration
    company.update_home_group_field
    company.manage_profile_setup_on_integration_change(company)
    company.manage_phone_format_conversion(company)
  end

  def ensure_unique_auth
    Rails.cache.delete("#{self.company_id}/authentication_type")
    integrations_to_disable = ['google_auth', 'shibboleth', 'active_directory_federation_services', 'okta', 'one_login', 'ping_id']
    integrations_to_disable.delete(self.api_name)
    company = self.company
    login_type = company.login_type
    company.integrations.where(api_name: integrations_to_disable).destroy_all
    company.login_type = login_type
    company.save!
  end

  def ensure_unique_provision
    Rails.cache.delete("#{self.company_id}/provisioning_type")
    integrations_to_disable = PROVISIONING_TYPES
    integrations_to_disable.delete(self.api_name)
    company = self.company
    company.integrations.where(api_name: integrations_to_disable).destroy_all
  end

  def configure_asana
    result = AsanaService::MockCall.new(self).perform
    unless result == true
      self.errors.add(:base, message: result.to_s)
      return false
    end
    true
  end

  def clear_asana_ids
    company = self.company
    return unless company.present?
    TaskUserConnection.joins(task: :workstream).where(workstreams: {company_id: company.id}).update_all(asana_id: nil)
  end

  def log_asana_errors
    LoggingService::IntegrationLogging.new.create(self.company, 'Asana', 'Configuration', nil, self.errors.to_json, 500) unless Rails.env == 'test'
  end

  def self.generate_scrypt_client_id company
    SCrypt::Password.create(company.domain + 'client_id' + Time.now.to_s).gsub(/[^0-9A-Za-z]/, '') + company.id.to_s
  end

  def self.generate_scrypt_client_secret company
    SCrypt::Password.create(company.domain + 'client_secret' + Time.now.to_s).last(40) + company.id.to_s
  end

  def self.generate_api_token(company, integration_name)
    JsonWebToken.encode({company_id: company.id, subdomain: company.subdomain, source: integration_name, timestamp: DateTime.now.strftime('%Q')}, 5.years.from_now)
  end

  private

  def clear_provision_cache
    Rails.cache.delete("#{self.company_id}/provisioning_type")
    true
  end

  def clear_payroll_cache
    Rails.cache.delete("#{self.company_id}/integration_type")
    true
  end

  def manage_payroll_integration_change
    return unless company.present?
    company.update_groups_from_integration
    company.update_home_group_field
    company.manage_profile_setup_on_integration_change(company)
    company.manage_phone_format_conversion(company)
  end

  def manage_company_codes_custom_field
    return unless company.present?
    ::IntegrationsService::AdpWorkforceNow.new(company).create_company_codes_custom_field(self)
    ::HrisIntegrations::AdpWorkforceNow::UpdateCompanyCodesFromAdpJob.perform_later(self.id)
  end

  def manage_tax_types_custom_field
    return unless company.present?
    ::IntegrationsService::AdpWorkforceNow.new(company).create_tax_types_custom_field(self)
  end

  def manage_worked_in_country_custom_field
    return unless company.present?
    ::IntegrationsService::AdpWorkforceNow.new(company).create_worked_in_country_custom_field(self)
    ::HrisIntegrations::AdpWorkforceNow::UpdateCountryAlphaCodesFromAdpJob.perform_later(self.id)
  end

  def manage_sin_expiry_date_custom_field; ::IntegrationsService::AdpWorkforceNow.new(company).create_sin_expiry_date_custom_field() if company end

  def clear_auth_cache
    Rails.cache.delete("#{self.company_id}/authentication_type")
    true
  end

  def clear_cache
    case self.api_name
    when 'jira'
      Rails.cache.delete("#{self.company_id}/jira_integration")
    when 'gsuite'
      Rails.cache.delete("#{self.company_id}/gsuite")
    when 'active_directory_federation_services'
      Rails.cache.delete("#{self.company_id}/active_directory_federation_services")
    end
    return true
  end

  def update_sapling_option_mappings_from_adp
    ::HrisIntegrations::AdpWorkforceNow::UpdateSaplingIntegrationOptionMappingsFromAdpJob.perform_later(self.id, true)
  end

  def update_adp_onboarding_templates
    ::HrisIntegrations::AdpWorkforceNow::UpdateOnboardingTemplatesFromAdpJob.perform_later(self.id)
  end

  def disable_on_linkedin
    AtsIntegrationsService::LinkedIn.new(self.company, nil, true).disable_extension(self.hiring_context)
  end

  def update_sapling_with_learn_upon
    ::LearningDevelopmentIntegrations::LearnUpon::UpdateSaplingUserFromLearnUponJob.perform_async(self.company.id)
  end

  def update_sapling_with_lessonly
    ::LearningDevelopmentIntegrations::Lessonly::UpdateSaplingUserFromLessonlyJob.perform_async(self.company.id)
  end

  def update_sapling_with_one_login
    ::SsoIntegrations::OneLogin::UpdateSaplingUserFromOneloginJob.perform_async(self.company.id)
  end

  def create_trinet_preference_field
    self.company.add_trinet_id_preference_field
  end

  def delete_trinet_preference_field
    self.company.remove_trinet_id_preference_field
  end

  def create_gsuite_fields
    ::SsoIntegrations::Gsuite::MapOuAndGroupsFieldJob.perform_async(self.company_id)
  end

  def remove_xero_connections
    ::HrisIntegrations::Xero::RemoveXeroConnection.perform_async(self.company.id, self.access_token, self.subscription_id)
  end
  
  def sync_okta_users
    ::Okta::SyncOktaEmployeesJob.perform_async(self.id)
  end
  
  def unsubsribe_workable(workable_api)
    return unless workable_api.present? && workable_api.subdomain.present? && workable_api.access_token.present? && workable_api.subscription_id.present?

    workable = AtsIntegrations::Workable.new(workable_api.company, workable_api)
    workable.unsubscribe
  end

  def log(company, integration_name, action, request = nil, response = {}, status= nil)
    logging = LoggingService::IntegrationLogging.new
    logging.create(company, integration_name, action, request, response, status)
  end

end
