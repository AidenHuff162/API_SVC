class CustomField < ApplicationRecord
  include FieldAuditing, CustomTableManagement

  has_paper_trail
  belongs_to :company
  belongs_to :company_with_deleted, -> { unscope(where: :deleted_at) }, class_name: 'Company', foreign_key: :company_id
  belongs_to :custom_table
  belongs_to :custom_section

  has_many :requested_fields, dependent: :destroy
  has_many :custom_field_values, dependent: :destroy
  has_many :custom_field_options, dependent: :nullify
  has_many :sub_custom_fields, dependent: :destroy
  has_many :custom_field_reports, dependent: :destroy
  has_many :field_histories, dependent: :destroy
  has_many :custom_snapshots, dependent: :destroy
  has_many :profile_template_custom_field_connections, dependent: :destroy
  has_many :active_custom_field_options, -> { where(active: :true) }, class_name: 'CustomFieldOption', foreign_key: :custom_field_id
  has_many :employment_options, class_name: 'CustomFieldOption'

  has_many :integration_field_mappings
  has_one :task

  accepts_nested_attributes_for :custom_field_values
  accepts_nested_attributes_for :custom_field_options, allow_destroy: true
  accepts_nested_attributes_for :sub_custom_fields, allow_destroy: true

  attr_accessor :updating_integration, :from_custom_group, :skip_validations

  enum section: { personal_info: 0, profile: 1, additional_fields: 2, paperwork: 3, private_info: 4 }
  enum display_location: { onboarding: 0, offboarding: 1, global: 2 }
  enum integration_group: { no_integration: 0, namely: 1, bamboo: 2, paylocity: 3, adp_wfn: 4, adp_wfn_profile_creation_and_bamboo_two_way_sync: 5, custom_group: 6 }
  enum field_type: { short_text: 0, long_text: 1, multiple_choice: 2, confirmation: 3, mcq: 4, social_security_number: 5, date: 6, address: 7, phone: 8, simple_phone: 9, number: 10, coworker: 11, multi_select: 12, employment_status: 13, currency: 14, social_insurance_number: 15, tax: 16, national_identifier: 17 } # relational: 18
  enum collect_from: { new_hire: 0, admin: 1, manager: 2 }
  enum ats_integration_group: { greenhouse: 0 }
  enum ats_mapping_section: { candidate: 0, job: 1, jobs: 2, offer: 3 }

  validate :employment_status_uniqueness
  validate :name_uniqueness, on: [:create, :update]
  validates :name, format: { with: /\A[^"]+\z/, message: I18n.t('validation.double_quotes_found') }
  FIELD_TYPE_WITH_OPTION = ['mcq', 'employment_status', 'multi_select']
  FIELD_TYPE_WITH_PLAIN_TEXT = ['short_text', 'long_text', 'confirmation', 'social_security_number', 'date', 'simple_phone', 'number', 'social_insurance_number']
  RESERVED_NAMES = ["Departments", "Locations", "User ID", "Profile Photo", "First Name", "Last Name", "Preferred Name", "Company Email", "Personal Email", "Start Date", "Access Permission", "Buddy", "About", "Linkedin", "Twitter", "Department", "Job Title", "Location", "Manager", "Status", "Termination Date", "Last Day Worked", "Termination Type", "Eligible for Rehire"]
  TAX_FIELDS_WITH_REGEX = { social_security_number: /\\d{3}-\\d{2}-\\d{4}/, social_insurance_number: /\\d{3}-\\d{3}-\\d{3}/ }

  default_scope { order(position: :asc) }
  scope :with_excluded_fields_for_webhooks, -> { where.not("name ILIKE ANY(ARRAY['%effective date%', '%user id%', '%profile photo%', '%access permission%'])") }
  scope :grouped_custom_fields, -> (group_option) { where.not(integration_group: group_option) }

  before_destroy :nullify_values
  after_update :remove_empty_hire_manager_forms, if: Proc.new { |custom_field| custom_field.saved_change_to_collect_from? && custom_field.collect_from != 'manager' }
  after_create :update_namely_ids, if: Proc.new { |cf| cf.namely? && cf.company && cf.company.is_namely_integrated }
  after_update :update_namely_ids, if: Proc.new { |cf| cf.namely? && cf.saved_change_to_mapping_key? && cf.company && cf.company.is_namely_integrated }
  after_create :update_bamboo_options, if: Proc.new { |cf| cf.company && ((cf.company.integration_types.include?("bamboo_hr") && cf.integration_group == "bamboo") || cf.integration_group == "adp_wfn_profile_creation_and_bamboo_two_way_sync") }
  after_update :update_bamboo_options, if: Proc.new { |cf| cf.saved_change_to_mapping_key? && cf.company && ((cf.company.integration_types.include?("bamboo_hr") && cf.integration_group == "bamboo") || cf.integration_group == "adp_wfn_profile_creation_and_bamboo_two_way_sync") }
  after_update :reposition_profile_templates, if: Proc.new { |cf| cf.saved_change_to_section? }
  before_save :track_subcustom_field_values, if: :if_nested_subcustom_fields_are_updated?
  after_save :update_field_histories_name, if: :saved_change_to_name?
  after_destroy :update_field_mapping
  # Generating unique API field id
  after_create :set_api_field_id
  # after_commit :flush_cache

  #Manage custom tables
  after_create { initialize_custom_group_position if self.custom_table_id && self.from_custom_group }
  after_create { create_custom_table_default_snapshots(self) if self.custom_table_id.present? }

  # Revamp code started. NOTE: Please contact with Zaeem before working in this block
  def self.find_by_name(name)
    self.find_by('custom_fields.name ~* ?', name)
  end

  def is_type_subfield?
    ['address', 'phone', 'currency', 'tax'].include?(self.field_type)
  end

  def is_type_option_field?
    FIELD_TYPE_WITH_OPTION.include?(self.field_type)
  end

  def is_type_plain_text?
    FIELD_TYPE_WITH_PLAIN_TEXT.include?(self.field_type)
  end

  # Revamp code ended

  def update_field_mapping
    self.integration_field_mappings.joins(:integration_instance).where(integration_instances: { api_identifier: 'kallidus_learn', company_id: self&.company_id }).destroy_all
    self.integration_field_mappings.joins(:integration_instance).where(integration_instances: { company_id: self&.company_id }).update_all(custom_field_id: nil, preference_field_id: "null", is_custom: false)
  end

  def self.typehHasSubFields(type)
    ['address', 'phone', 'currency', 'tax', 'national_identifier'].include?(type) # << 'relational'
  end

  def update_namely_ids
    UpdateSaplingCustomGroupsFromNamelyJob.perform_later(self.company)
  end

  def update_bamboo_options
    ::HrisIntegrations::Bamboo::UpdateSaplingGroupsFromBambooJob.perform_later(self.company)
  end

  def self.parse_phone_string_to_hash(phone_string)
    Phonelib.default_country = "US"

    ret_val = nil
    begin
      phone = Phonelib.parse(phone_string)
      if phone.present? && phone.valid?
        country_alpha3 = nil
        country_alpha3 = ISO3166::Country.find_country_by_alpha2(phone.country).alpha3 if phone.country
        area_code = phone.area_code
        phone_number = nil
        phone_number = phone.national(false)
        phone_number = phone.national(false).sub(area_code, '') if phone_number && area_code

        national_prefix = ISO3166::Country.find_country_by_alpha3(country_alpha3)&.national_prefix
        national_prefix&.split('')&.each do |prefix|
          phone_number[0] = '' if phone_number && phone_number[0] == prefix
        end

        ret_val = { country_alpha3: country_alpha3, area_code: area_code, phone: phone_number }
      end
    rescue Exception => e
    end
    ret_val
  end

  def self.get_custom_field(company, field_name)
    company.custom_fields.find_by('name ILIKE ?', field_name)
  end

  def self.get_sub_custom_field_value(custom_field, field_name, user_id)
    custom_field.sub_custom_fields.find_by('name ILIKE ?', field_name).get_sub_custom_field_values_by_user(user_id).value_text rescue nil
  end

  def self.get_custom_field_value(custom_field, user_id)
    custom_field.get_custom_field_values_by_user(user_id).value_text rescue nil
  end

  def self.get_coworker_value(custom_field, user_id)
    custom_field.get_custom_field_values_by_user(user_id).coworker rescue nil
  end

  def self.get_mcq_custom_field_value(custom_field, user_id)
    custom_field.custom_field_options.find_by_id(custom_field.get_custom_field_values_by_user(user_id).custom_field_option_id).option rescue nil
  end

  def self.get_multiselect_custom_field_value(custom_field, user_id)
    custom_field.custom_field_options.where(id: custom_field.get_custom_field_values_by_user(user_id).checkbox_values).pluck(:option).join(', ') rescue nil
  end

  def self.convert_phone_number_to_international_phone_number(custom_field, user_id)
    phone_number = self.parse_phone_string_to_hash(self.get_custom_field_value(custom_field, user_id))
    phone_number rescue nil
  end

  def self.convert_international_phone_number_to_phone_number(custom_field, user_id)

    country = self.get_sub_custom_field_value(custom_field, 'Country', user_id)
    area_code = self.get_sub_custom_field_value(custom_field, 'Area Code', user_id)
    phone = self.get_sub_custom_field_value(custom_field, 'Phone', user_id)

    return nil if !phone.present?

    country_alpha3 = ISO3166::Country.find_country_by_alpha3(country) if country.present?
    phone_number = [country_alpha3.country_code, area_code, phone].join('') rescue nil
    phone_number = phone_number.gsub(/\W/, '') if phone_number.present?

    return phone_number
  end

  def self.get_custom_field_params(custom_field, field_type)
    custom_field_params = {
      company_id: custom_field.company_id,
      section: custom_field.section,
      position: custom_field.position,
      name: custom_field.name,
      help_text: custom_field.help_text,
      default_value: custom_field.default_value,
      field_type: field_type,
      required: custom_field.required,
      required_existing: custom_field.required_existing,
      locks: custom_field.locks
    }
  end

  def remove_empty_hire_manager_forms
    self.company.remove_empty_hire_manager_forms
  end

  def checkbox_values user_id
    cb_values = self.get_custom_field_values_by_user(user_id).checkbox_values
    CustomFieldOption.where(id: cb_values).pluck(:option).join(', ')
  end

  def get_custom_field_values_by_user(user_id, approval_profile_page = nil)
    #Key Rails.cache.fetch(subCustomField/UserId/custom_field_values)
    # Need to find custom_field update_column
    # Rails.cache.fetch([self.id, user_id, 'custom_field_values'] , expires_in: 5.days) do
    if approval_profile_page.present? && CustomSectionApproval.is_custom_field_in_requested(self.id, user_id) > 0
      value = CustomSectionApproval.get_custom_field_in_requested(self.id, user_id)
      value.first
    else
      value = self.custom_field_values.find_by(user_id: user_id)
      (value.present? && value.deleted_at.nil?) ? value : nil
    end
    # end
  end

  def flush_cache
    user_ids = self.custom_field_values.pluck(:user_id).uniq
    user_ids.each do |user_id|
      Rails.cache.delete([self.id, user_id, 'custom_field_values'])
    end
    true
  end

  def get_changed_sub_custom_field_values
    changed_values = []
    sub_fields = self.sub_custom_fields.sort_by &:id
    sub_fields.each do |scf|
      scf.custom_field_values.map { |value| changed_values << value if value.has_changes_to_save? }
    end
    # self.sub_custom_fields.map{|scf| scf.custom_field_values.map{|value| changed_values << value if value.changed? }}
    changed_values
  end

  def if_nested_subcustom_fields_are_updated?
    changed_custom_field_values = []
    if self.sub_custom_fields.present?
      changed_custom_field_values = get_changed_sub_custom_field_values
    end
    changed_custom_field_values.size > 0
  end

  def track_subcustom_field_values
    changed_custom_field_values = []
    changed_fields_and_values = {}
    if self.sub_custom_fields.present?
      changed_custom_field_values = get_changed_sub_custom_field_values
      changed_custom_fields = changed_custom_field_values.map{|cfv| {custom_field: cfv.sub_custom_field.custom_field, user: cfv.user, integration: cfv.updating_integration} }
      if self.field_type.eql?('address')
        changed_custom_field_values.each{ |cfv| changed_fields_and_values[cfv.sub_custom_field.name] = cfv.value_text }
        changed_custom_fields.uniq.each do |custom_field|
          track_changed_fields(custom_field[:custom_field], custom_field[:user], changed_fields_and_values.to_h,
                               custom_field[:integration])
        end
      else
        changed_custom_fields.uniq.each do |custom_field|
          track_changed_fields(custom_field[:custom_field], custom_field[:user],
                               changed_custom_field_values.collect(&:value_text).join(', '),
                               custom_field[:integration])
        end
      end
    end
  end

  def employment_status_uniqueness
    if self.field_type == 'employment_status'
      field_count = CustomField.joins(:company)
                               .where(companies: { id: self.company_id }, field_type: 13)
                               .where.not(id: self.id)
                               .count
      errors.add(:FieldType, 'Field type not uniq.') if field_count > 0
    end
  end

  def name_uniqueness
    if self.name_change_to_be_saved && !self.skip_validations && self.name != "Effective Date" && (RESERVED_NAMES.include?(self.name) || CustomField.where(company_id: self.company_id, name: self.name, deleted_at: nil).where.not(id: self.id).count > 0) || is_effective_date_present
      errors.add(:name, ' is already in use.')
    end
  end

  def is_effective_date_present
    self.name.downcase == "effective date" && ((self.section.present? && self.company.custom_fields.joins(:custom_section).where.not(id: self.id).where("lower(name) LIKE ?", 'effective date').present?) || (self.custom_table.present? && self.custom_table&.custom_fields&.where.not(id: self.id).where("lower(name) LIKE ?", 'effective date').present?))
  end

  def nullify_values
    return if self.id.nil?
    ProfileTemplateCustomFieldConnection.with_deleted.where(custom_field_id: self.id).delete_all
    CustomFieldValue.with_deleted.where(custom_field_id: self.id).delete_all
    Task.with_deleted.where(custom_field_id: self.id).update_all(custom_field_id: nil)
    SubCustomField.where(custom_field_id: self.id).destroy_all
  end

  def set_api_field_id
    update_column(:api_field_id, generate_api_field_id)
  end

  def generate_api_field_id
    "PFID#{rand(1_000_000_000 .. 9_999_999_999)}#{id}"
  end

  #temporary method for active-admin
  def profile_setup
    'this is virtual method!'
  end

  def initialize_custom_group_position
    preference_field_position = self.company.prefrences['default_fields'].select { |default_field| default_field['custom_table_property'] == self.custom_table.custom_table_property }.max_by { |k, v| k['position'] }['position'].to_i rescue 0
    default_field_position = self.custom_table.custom_fields.where("position > ?", preference_field_position).reorder('position desc').take.try(:position).to_i
    position = (preference_field_position > default_field_position) ? preference_field_position + 1 : default_field_position + 1

    update_column(:position, position)
  end

  def phone_field_values(user_id)
    raise "CustomField#phone_field_values was called on an invalid CustomField" unless self.field_type == "phone"
    CustomFieldValue.where(user_id: user_id, sub_custom_field_id: self.sub_custom_fields.pluck(:id)).order(:sub_custom_field_id).map(&:value_text)
  end

  def address_field_values(user_id)
    raise "CustomField#address_field_values was called on an invalid CustomField" unless self.field_type == "address"
    CustomFieldValue.where(user_id: user_id, sub_custom_field_id: self.sub_custom_fields.pluck(:id)).order(:sub_custom_field_id).map(&:value_text)
  end

  def reposition_profile_templates
    self.profile_template_custom_field_connections.includes(:profile_template).find_each do |conn|
      conn.profile_template.reposition_field_connections(conn, self)
    end
    true
  end

  def duplicate
    new_field = self.dup
    self.sub_custom_fields.each do |scf|
      dupe_sub_field = scf.dup
      dupe_sub_field.custom_field_id = nil
      new_field.sub_custom_fields << dupe_sub_field
    end
    self.custom_field_options.each do |option|
      dupe_option = option.dup
      dupe_option.custom_field_id = nil
      new_field.custom_field_options << dupe_option
    end
    pattern = "%#{new_field.name.to_s[0, new_field.name.length - 1]}%"
    duplicate_name = self.name.insert(0, 'Copy of ')
    duplicate_name = duplicate_name + " (#{self.company.custom_fields.where("name LIKE ?", pattern).count})"
    new_field.name = duplicate_name
    new_field.position = get_position
    new_field.save
    new_field
  end

  def self.get_coworker_field_name(field_id)
    if field_id == 'bdy'
      'Buddy'
    else
      CustomField.find_by(id: field_id)&.name
    end
  end

  def self.get_formatted_home_address(custom_field, address_format, user_id)
    formatted_address = ''
    address_format.each_with_index do |address_name, index|
      sub_custom_field = custom_field.sub_custom_fields.find_by('name ILIKE ?', address_name)
      value = self.get_sub_custom_field_value(custom_field, sub_custom_field.name, user_id) if sub_custom_field.present?
      if value.present?
        formatted_address = formatted_address + value
        formatted_address = formatted_address + ',' if index != address_format.length - 1
      end
    end
    formatted_address
  end

  def self.get_custom_field_name(api_field_ids, current_company)
    current_company.custom_fields.map { |field| field["name"] if api_field_ids.include?(field['api_field_id']) }.reject(&:nil?)
  end

  def get_mapping_field_option(value)
    self.custom_field_options.where('option ILIKE ?', value).take&.option
  end

  def get_option_by_wid(wid)
    self.custom_field_options.find_by(workday_wid: wid)
  end

  private

  def get_position
    section = self.section
    custom_table = self.custom_table
    if custom_table.present?
      default_fields = self.company.prefrences["default_fields"].select { |default_field| default_field["custom_table_property"] == custom_table.custom_table_property && default_field["profile_setup"] == "custom_table" }
      custom_fields = custom_table.custom_fields.map { |field| field.as_json }
    else
      default_fields = self.company.prefrences["default_fields"].select { |default_field| default_field["section"] == section && default_field["profile_setup"] == "profile_fields" }
      custom_fields = self.company.custom_fields.where(section: section).map { |field| field.as_json }
    end

    all_fields = [].concat(custom_fields).concat(default_fields).sort_by { |conn| conn["position"].to_i }
    position = all_fields[-1]["position"] + 1
  end

  def self.get_valid_custom_field_position(company, section)
    cfs = company.custom_fields.where(custom_fields: { section: section }).where.not(custom_fields: { section: nil }).as_json
    dfs = company.prefrences['default_fields'].select { |default_field| default_field['section'] == 'personal_info' && default_field['profile_setup'] == 'profile_fields' }
    destination_connections = [].concat(cfs).concat(dfs).sort_by { |conn| conn["position"].to_i }
    position = destination_connections[-1]["position"] + 1
  end

  def update_field_histories_name
    self.field_histories.update_all(field_name: self.name) if self.field_histories.present?
  end
end
