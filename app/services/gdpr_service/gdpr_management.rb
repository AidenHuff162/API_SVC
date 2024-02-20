class GdprService::GdprManagement
  attr_reader :user, :regulation

  def initialize(user)
    @user = user
    @regulation = user.company.general_data_protection_regulation if user.present?
  end

  def perform
    return unless can_apply_action?
    regulation.anonymize? ? anonymize : delete
  end

  private

  def can_apply_action?
    user.present? && user.departed? && (user.termination_date+365) <= Date.today && regulation.present? && regulation.action_location.reject(&:blank?).present? && !user.is_gdpr_action_taken.present? && user.gdpr_action_date.present? && user.gdpr_action_date <= Date.today && (regulation.action_location.include?('all') || regulation.action_location.include?(user.location_id.try(:to_s)))
  end

  def delete
    user.update_column(:deletion_through_gdpr, true)
    user.destroy!
  end

  def anonymize
    # User fields anonymization
    anonymize_user_data

    custom_fields = user.company.custom_fields
    # Address field anonymization
    anonymize_address_field_data(custom_fields)
    # Phone field anonymization
    anonymize_phone_field_data(custom_fields)
    # Social Security field anonymization
    anonymize_social_security_field_data(custom_fields)
    # Emergency field anonymization
    anonymize_emergency_field_data(custom_fields)
    # Social Insurance field anonymization
    anonymize_social_insurance_field_data(custom_fields)

    user.update_column(:is_gdpr_action_taken, true)
  end

  def anonymize_user_data
    user_data = {
      first_name: 'Anonymized',
      last_name: Faker::Number.number(5),
      email: "anonymized@#{Faker::Number.number(6)}",
      personal_email: "anonymized@#{Faker::Number.number(7)}",
      preferred_name: 'Anonymized',
      uid: "anonymized@#{Faker::Number.number(8)}",
      state: 'inactive',
      bamboo_id: nil,
      namely_id: nil,
      adp_wfn_us_id: nil,
      adp_wfn_can_id: nil,
      okta_id: nil,
      one_login_id: nil,
      deputy_id: nil,
      fifteen_five_id: nil,
      preferred_full_name: 'Anonymized'
    }

    temp_user_data = {
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      personal_email: user.personal_email,
      preferred_name: user.preferred_name,
      uid: user.uid,
      state: user.state,
      bamboo_id: user.bamboo_id,
      namely_id: user.namely_id,
      adp_wfn_us_id: user.adp_wfn_us_id,
      adp_wfn_can_id: user.adp_wfn_can_id,
      okta_id: user.okta_id,
      one_login_id: user.one_login_id,
      preferred_full_name: user.preferred_full_name,
      deputy_id: user.deputy_id,
      fifteen_five_id: user.fifteen_five_id
    }

    create_anonymized_datum({user_data: temp_user_data})
    user.update_columns(user_data)
  end

  def anonymize_address_field_data(custom_fields = nil)
    return unless custom_fields.present?

    address_custom_fields = custom_fields.where(field_type: CustomField.field_types[:address])
    address_data = {}

    address_custom_fields.try(:each) do |address_custom_field|
      address_data["#{address_custom_field.id}"] = user.get_custom_field_value_text(nil, true, nil, address_custom_field)

      address_custom_field.sub_custom_fields.try(:each) do |sub_address_custom_field|
        value_text = nil
        case sub_address_custom_field.name.try(:downcase)
        when 'line 1', 'line 2'
          value_text = '123 City Street'
        when 'city'
          value_text = 'San Francisco, California'
        when 'state'
          value_text = 'CA'
        when 'zip'
          value_text = '94100'
        end
        update_sub_custom_field_value(sub_address_custom_field.id, value_text) if value_text.present?
      end
    end

    create_anonymized_datum({address_data: address_data})
  end

  def anonymize_phone_field_data(custom_fields = nil)
    return unless custom_fields.present?
    phone_data = {}

    simple_phone_custom_fields = custom_fields.where(field_type: CustomField.field_types[:simple_phone])
    simple_phone_custom_fields.try(:each) do |simple_phone_custom_field|
      phone_data["#{simple_phone_custom_field.id}"] = user.get_custom_field_value_text(nil, false, nil, simple_phone_custom_field)
      update_custom_field_value(simple_phone_custom_field.id, '000-00000000')
    end

    phone_custom_fields = custom_fields.where(field_type: CustomField.field_types[:phone])
    phone_custom_fields.try(:each) do |phone_custom_field|
      phone_data["#{phone_custom_field.id}"] = user.get_custom_field_value_text(nil, true, nil, phone_custom_field)

      phone_custom_field.sub_custom_fields.try(:each) do |sub_phone_custom_field|
        value_text = nil
        case sub_phone_custom_field.name.try(:downcase)
        when 'area code'
          value_text = '000'
        when 'phone'
          value_text = '0000000'
        end
        update_sub_custom_field_value(sub_phone_custom_field.id, value_text) if value_text.present?
      end
    end

    create_anonymized_datum({phone_data: phone_data})
  end

  def anonymize_social_security_field_data(custom_fields = nil)
    return unless custom_fields.present?
    ssn_data = {}

    social_security_field_fields = custom_fields.where(field_type: CustomField.field_types[:social_security_number])
    social_security_field_fields.try(:each) do |social_security_field_field|
      ssn_data["#{social_security_field_field.id}"] = user.get_custom_field_value_text(nil, false, nil, social_security_field_field)
      update_custom_field_value(social_security_field_field.id, '000000000')
    end

    create_anonymized_datum({ssn_data: ssn_data})
  end

  def anonymize_social_insurance_field_data(custom_fields = nil)
    return unless custom_fields.present?
    sin_data = {}

    social_insurance_number_fields = custom_fields.where(field_type: CustomField.field_types[:social_insurance_number])
    social_insurance_number_fields.try(:each) do |social_insurance_number_field|
      sin_data["#{social_insurance_number_field.id}"] = user.get_custom_field_value_text(nil, false, nil, social_insurance_number_field)
      update_custom_field_value(social_insurance_number_field.id, '000000000')
    end

    create_anonymized_datum({sin_data: sin_data})
  end

  def anonymize_emergency_field_data(custom_fields = nil)
    return unless custom_fields.present?
    emergency_data = {}

    emergency_contact_fields = custom_fields.where('name ILIKE ? AND field_type = ?', '%Emergency%', CustomField.field_types[:short_text]).where.not('name ILIKE ?', '%Email%')
    emergency_contact_fields.try(:each) do |emergency_contact_field|
      emergency_data["#{emergency_contact_field.id}"] = user.get_custom_field_value_text(nil, false, nil, emergency_contact_field)
      update_custom_field_value(emergency_contact_field.id, 'Anonymized')
    end

    emergency_contact_fields = custom_fields.where('name ILIKE ? AND field_type = ?', '%Emergency%', CustomField.field_types[:short_text]).where('name ILIKE ?', '%Email%')
    emergency_contact_fields.try(:each) do |emergency_contact_field|
      emergency_data["#{emergency_contact_field.id}"] = user.get_custom_field_value_text(nil, false, nil, emergency_contact_field)
      update_custom_field_value(emergency_contact_field.id, 'anonymized@contact.com')
    end

    create_anonymized_datum({emergency_data: emergency_data})
  end

  def update_custom_field_value(custom_field_id = nil, value_text = nil)
    return unless custom_field_id.present? && value_text.present?
    custom_field_value = user.custom_field_values.find_by(custom_field_id: custom_field_id)

    return unless custom_field_value.present? && custom_field_value.value_text.present?

    custom_field_value.value_text = value_text
    custom_field_value.save!
  end

  def update_sub_custom_field_value(sub_custom_field_id = nil, value_text = nil)
    return unless sub_custom_field_id.present? && value_text.present?
    custom_field_value = user.custom_field_values.find_by(sub_custom_field_id: sub_custom_field_id)

    return unless custom_field_value.present? && custom_field_value.value_text.present?

    custom_field_value.value_text = value_text
    custom_field_value.save!
  end

  def create_anonymized_datum(params)
    anonymized_datum = user.anonymized_datum
    if !anonymized_datum.present?
      AnonymizedDatum.create(params.merge!(user_id: user.id))
      user.reload
    else
      anonymized_datum.update(params)
    end
  end
end
