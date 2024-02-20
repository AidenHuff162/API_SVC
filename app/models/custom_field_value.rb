class CustomFieldValue < ApplicationRecord
  include FieldAuditing
  include CalendarEventsCrudOperations, UserStatisticManagement, LoggingManagement

  has_paper_trail
  acts_as_paranoid
  belongs_to :custom_field, touch: true
  belongs_to :sub_custom_field, touch: true
  belongs_to :user
  belongs_to :custom_field_option
  belongs_to :coworker, class_name: 'User', foreign_key: :coworker_id

  validates :user_id, uniqueness: { scope: :custom_field_id }, if: -> { user_id.present? && custom_field_id.present? }
  validates :user_id, uniqueness: { scope: :sub_custom_field_id }, if: -> { user_id.present? && sub_custom_field_id.present? }
  validates_with UpdateCustomFieldValueCompanyValidator

  after_save :initiate_birthday_event, if: Proc.new { |cfv| cfv.saved_change_to_value_text? && cfv.custom_field.present? && ['Date of Birth', 'Birth Date'].include?(cfv.custom_field.name) && cfv.user.present? && cfv.user.active? }
  after_update { remove_birthday_event if belong_to_birthday_custom_field? && self.value_text.blank?}
  before_destroy { remove_birthday_event if belong_to_birthday_custom_field? }

  after_save :track_changed_fields, if: :run_after_update_field_audit_callback?
  after_save :update_assigned_polices_to_user, if: Proc.new{ |cfv| cfv.custom_field.try(:field_type) == 'employment_status'}
  after_save :update_org_chart_if_custom_group, if: Proc.new { |cfv| !cfv.skip_org_chart_callback && cfv.user.present? && cfv.user.company.present? && cfv.user.company.organization_chart.present? && cfv.custom_field.present? && !cfv.custom_field.no_integration? && cfv.saved_change_to_custom_field_option_id?}

  after_commit :flush_cache

  attr_accessor :updating_integration, :manage_history_sub_custom_field, :skip_org_chart_callback

  attr_encrypted_options.merge!(:encode => true)
  attr_encrypted :value_text, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']

  CUSTOM_FIELD_VALUE_TYPES = ['short_text', 'long_text', 'social_security_number', 'date', 'simple_phone', 'number', 'address', 'confirmation', 'social_insurance_number']
  AUDITING_FIELDS = ['encrypted_value_text', 'checkbox_values', 'custom_field_option_id', 'coworker_id']

  # Revamp code started. NOTE: Please contact with Zaeem before working in this block
  def self.find_by_user_and_field_id(user, field_id)
    Rails.cache.fetch("user_#{user.id}/custom_field_#{field_id}", expires_in: 8.hours) do
      custom_field = user.company.custom_fields.find_by_id(field_id)
      custom_field_value_params = custom_field.is_type_subfield? ? { sub_custom_field_id: custom_field.sub_custom_fields.pluck(:id) }
                                    : { custom_field_id: custom_field.id }
      custom_field_values = self.where(custom_field_value_params.merge(user_id: user.id))
      CustomFieldValueManager::StructureFormatter.call(custom_field, custom_field_values)
    end
  end

  # Revamp code ended
  def self.set_custom_field_value(user = nil, field_name = nil, value_text = nil, sub_field_name = nil, is_custom_field = true, default_field = nil, is_custom_table_field = false, create_histroy_for_sub_custom_field = false, skip_org_chart_callback = false)
    return if !user.present? || (!field_name.present? && !default_field)

    if !default_field.present?
      if !is_custom_field.present?
        return if !sub_field_name.present?
        field = SubCustomField.get_sub_custom_field(user.company, field_name, sub_field_name)
      else
        field = CustomField.get_custom_field(user.company, field_name)
      end
    else
      if !is_custom_field.present?
        return if !sub_field_name.present?
        field = SubCustomField.get_sub_custom_field(user.company, nil, sub_field_name, default_field)
      else
        field = default_field
      end
    end

    return if !field.present?
    custom_field_value = field.custom_field_values.find_or_initialize_by(user_id: user.id)
    custom_field_value.manage_history_sub_custom_field = create_histroy_for_sub_custom_field
    custom_field_value.updating_integration = user.updating_integration if is_custom_field.present?
    if CUSTOM_FIELD_VALUE_TYPES.include? field.field_type
      if custom_field_value.value_text != value_text
        custom_field_value.value_text = value_text
        return unless custom_field_value.save
      end
    elsif field.coworker?
      coworker_id = nil
      if is_custom_table_field.present? && value_text.present?
        coworker_id = user.company.users.find_by(id: value_text).try(:id)
      elsif is_custom_table_field.blank? && value_text.present?
        coworker_id = user.company.users.find_by(guid: value_text).try(:id)
        coworker_id = user.company.users.find_by(id: value_text).try(:id)
        coworker_id = user.company.users.find_by(email: value_text).try(:id) if !coworker_id
        coworker_id = user.company.users.find_by(personal_email: value_text).try(:id) if !coworker_id
      end
      custom_field_value.coworker_id = coworker_id
      return unless custom_field_value.save
    elsif field.multi_select?
      if custom_field_value.checkbox_values != value_text
        custom_field_value.checkbox_values = value_text
        return unless custom_field_value.save
      end
    else
      if custom_field_value.custom_field_option_id != CustomFieldOption.get_custom_field_option(field, value_text).try(:id)
        custom_field_value.custom_field_option_id = CustomFieldOption.get_custom_field_option(field, value_text).try(:id)
        custom_field_value.skip_org_chart_callback = skip_org_chart_callback
        return unless custom_field_value.save
      end
    end
    custom_field_value
  end

  def run_after_update_field_audit_callback?
    auditing_fields_updated? and check_if_sub_custom_field_exits
  end

  def flush_cache
    field_id = self.custom_field_id ? self.custom_field_id : self.sub_custom_field&.custom_field_id
    Rails.cache.delete("user_#{self.user_id}/custom_field_#{field_id}")

    if self.user_id.present?
      # Rails.cache.delete([self.sub_custom_field_id, self.user_id, 'sub_custom_field_values']) if self.sub_custom_field_id.present?
      Rails.cache.delete("#{self.user_id}/employee_type") if self.custom_field&.field_type == 'employment_status'
    end
    true
  end

  def safe_encoded_value_text
    begin
      # Determine if serialization will cause error
      self.value_text.to_json
      self.value_text
    rescue
      self.value_text&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    end
  end

  private

  def update_assigned_polices_to_user 
    option_ids = self.saved_changes[:custom_field_option_id]
    user = self.user
    create_general_logging(user&.company, "Cache deleted for the employee type", { user_id: user&.id }) if user&.company&.subdomain == 'quality'
    if user.present?
      Rails.cache.delete("#{user.id}/employee_type")
      if option_ids.present?
        old_status = option_ids[0]
        new_status = option_ids[1]
        self.user.update_assigned_policies(old_status, old_status, new_status)
      end
    end
  end

  def initiate_birthday_event
    self.user.create_date_of_birth_calendar_event self.value_text
    self.user.update_email_schedule_date self.value_text
  end

  def remove_birthday_event
    self&.user&.birthday_calendar_events&.delete_all
  end

  def get_option_by_id id
    return nil unless id.present?
    self.custom_field.custom_field_options.where(id: id).take.try(:option)
  end

  def check_if_sub_custom_field_exits
    return self.manage_history_sub_custom_field ? true : (self.sub_custom_field.present?) ? false : true
  end

  def self.set_sub_custom_field_value(user, field_name, custom_field_value, sub_field_name)
    custom_field = CustomField.get_custom_field(user.company, field_name)
    if custom_field.present?
      sub_custom_field = custom_field.sub_custom_fields.find_by('name ILIKE ?', sub_field_name)
      if sub_custom_field.present? && sub_custom_field.field_type == 'short_text'
        user_sub_custom_field_value = sub_custom_field.custom_field_values.find_or_initialize_by(user_id: user.id)
        user_sub_custom_field_value.value_text = custom_field_value
        user_sub_custom_field_value.save!
      end
    end
  end

  def update_org_chart_if_custom_group
    self.user.run_update_organization_chart_job(options = { calculate_custom_groups: true, calculate_team_and_location: false })
  end

  def belong_to_birthday_custom_field?
    ['Date of Birth', 'Birth Date'].include?(self&.custom_field&.name)
  end

end
