module FieldAuditing
  extend ActiveSupport::Concern
  attr_accessor :field_audit_integration_id

  def track_changed_fields custom_field = nil, user = nil, new_field_value = nil , sub_field_integration = nil
    begin
      if custom_field.present? && sub_field_integration.present?
        return if custom_field.company_id != user.company_id
        user.field_histories.create(field_name: custom_field.name, new_value: new_field_value, integration_id: sub_field_integration.id , field_type: get_custom_field_type(custom_field), custom_field_id: custom_field.id)
      elsif custom_field.present?
        return if User.current.blank? || custom_field.company_id != User.current.company_id
        user.field_histories.create(field_name: custom_field.name, new_value: new_field_value, field_changer_id: User.current.id, field_type: get_custom_field_type(custom_field), custom_field_id: custom_field.id)
      else
        updated_auditable_fields = self.class.name.constantize::AUDITING_FIELDS & self.saved_changes.transform_values(&:first).keys
        updated_auditable_fields.each do |field|
          field_type = self.class.name == 'CustomFieldValue' ? get_custom_field_type(manage_custom_field_for_history()) : get_attribute_input_type(field)  
          create_field_history_record(field, field_type)
        end
      end
    rescue Exception => e
    end
  end

  def manage_custom_field_for_history
    return self.manage_history_sub_custom_field ? self.sub_custom_field : self.custom_field 
  end

  def auditing_fields_updated?
    class_object = self.class.name.constantize
    auditable_fields = class_object::AUDITING_FIELDS
    updated_fields = self.saved_changes.transform_values(&:first).keys
    (auditable_fields & updated_fields).size > 0
  end

  def get_actual_field_name field_name
    case field_name
      when 'Department'
        'Team'
      when 'Division'
        'Team'
      when 'Job Title'
        'Title'
      when 'Employment Status'
        'Employee Type'
      when 'Access Permission'
        'Role'
      when 'About'
        'About You'
      when 'Eligible for Rehire'
        'Eligible For Rehire'
      when 'GitHub'
        'Github'
      when 'Company Email'
        'Email'
      else
        field_name
    end
  end

  private

  def create_field_history_record field, field_type
    changer_id = if User.current.present?
      User.current.id
    elsif self.class.name == 'CustomFieldValue'
      get_custom_table_edited_by((self.custom_field || self.sub_custom_field&.custom_field)&.custom_table)
    end
    if !changer_id
      # fetching account owner if User.current is not set
      changer_id = self.user.company.users.where(role: 2).first.id if self.class.name == 'CustomFieldValue'
      changer_id = self.company.users.where(role: 2).first.id if self.class.name == 'User'
    end
    company_id = User.find_by_id(changer_id).company.id
    if self.class.name == 'CustomFieldValue'
      custom_field = set_custom_field
      return if custom_field.company.id != company_id
      if self.updating_integration.present?
        self.user.field_histories.create(field_name: custom_field.name, new_value: custom_field_value(custom_field), integration_instance_id: self.updating_integration.id, field_type: field_type, custom_field_id: custom_field.id)
      else
        self.user.field_histories.create(field_name: custom_field.name, new_value: custom_field_value(custom_field), field_changer_id: changer_id, field_type: field_type, custom_field_id: custom_field.id)
      end
    else
      return if self.class.name == 'Profile' && self.user.company_id != company_id
      return if self.class.name == 'User' && self.company_id != company_id
      if self.updating_integration.present?
        self.field_histories.create(field_name: field.titleize, new_value: new_field_value(field,self[field].to_s), integration_instance_id: self.updating_integration.id, field_type: field_type)
      else
        self.field_histories.create(field_name: field.titleize, new_value: new_field_value(field,self[field].to_s), field_changer_id: changer_id, field_type: field_type)
      end
    end
  end

  def new_field_value field, new_value
    new_value_to_be_persisted = nil
    if self.class.reflect_on_all_associations.map(&:foreign_key).map(&:to_s).uniq.include? field
      begin
        field = field.gsub('_id', '')
        associated_object = self.public_send field
        new_value_to_be_persisted = associated_object.get_object_name
      rescue Exception => e

      end
    elsif self.class.defined_enums.present? and self.class.defined_enums.keys.include? field
      new_value_to_be_persisted = self.class.defined_enums[field].key(new_value.to_i).titleize
    else
      new_value_to_be_persisted = new_value
    end
    new_value_to_be_persisted
  end

  def custom_field_value custom_field, user = nil
    user_object = user.present? ? user : self.user
    if custom_field.field_type == 'multi_select'
      self.custom_field.checkbox_values(self.user.id)
    elsif custom_field.custom_table_id.present?
      user_object.get_custom_field_value_text(nil, false, nil, custom_field, false, nil, false)
    else
      user_object.get_custom_field_value_text(custom_field.name, false, nil, nil, false, nil, false, false, false, false, 'US', false, true)
    end
  end

  def set_custom_field
    sub_custom_field = self.sub_custom_field
    if sub_custom_field.present?
      sub_custom_field.custom_field
    else
      self.custom_field
    end
  end

  def get_custom_field_type custom_field
    case custom_field.field_type
      when 'short_text', 'long_text'
        'text'
      when 'mcq', 'multiple_choice'
        'mcq'
      when 'date'
        'date'
      when 'coworker'
        'autocomplete'
      when 'multi_select'
        'multi_select'
      when 'confirmation'
        'confirmation'
      when 'phone', 'simple_phone', 'number'
        'string'
      when 'employment_status'
        'employment_status'
      when 'social_security_number'
        'social_security_number'
      when 'social_insurance_number'
        'social_insurance_number'
      else
        'text'
    end
  end

  def get_custom_table_edited_by(custom_table)
    return unless custom_table

    custom_table.custom_table_user_snapshots
                .find_by(user_id: self.user_id, state: CustomTableUserSnapshot.states[:applied])&.edited_by_id
  end
end
