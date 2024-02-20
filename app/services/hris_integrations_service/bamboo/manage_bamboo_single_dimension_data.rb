class HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData
  attr_reader :user, :bamboo_data, :custom_fields, :address_sub_custom_fields, :user_fields, :address_custom_fields

  def initialize(user)
    @user = user

    # Key and their value should be unique
    @address_custom_fields = [ 'home address' ]
    @custom_fields = {
      'date of birth' => :dateOfBirth,
      'social security number' => :ssn,
      'race/ethnicity' => :ethnicity,
      'mobile phone number' => :mobilePhone,
      'home phone number' => :homePhone,
      'federal marital status' => :maritalStatus,
      'gender' => :gender,
      'middle name' => :middleName,
      'home address' => :homeAddress
    }
    @address_sub_custom_fields = {
      :line1 => :address1,
      :line2 => :address2,
      :city => :city,
      :zip => :zipcode,
      :state => :state,
      :country => :country,
    }
    @user_fields = {
      "first_name" => :firstName,
      "last_name" => :lastName,
      "preferred_name" => :nickName,
      "email" => :workEmail,
      "personal_email" => :homeEmail,
      "start_date" => :hireDate
    }
  end

  def prepare_user_data
    data = {}

    data[:firstName] = user.first_name
    data[:lastName] = user.last_name
    data[:workEmail] = user.email
    data[:homeEmail] = user.personal_email
    data[:hireDate] = user.start_date.to_s
    data[:nickName] = user.preferred_name

    data
  end

  def prepare_custom_data
    data = {}

    data[custom_fields['date of birth']] = user.get_custom_field_value_text(custom_fields.key(:dateOfBirth)) if custom_fields['date of birth']
    data[custom_fields['social security number']] = user.get_custom_field_value_text(custom_fields.key(:ssn)) if custom_fields['social security number']
    data[custom_fields['race/ethnicity']] = user.get_custom_field_value_text(custom_fields.key(:ethnicity)) if custom_fields['race/ethnicity']
    data[custom_fields['mobile phone number']] = user.get_custom_field_value_text(custom_fields.key(:mobilePhone)) if custom_fields['mobile phone number']
    data[custom_fields['home phone number']] = user.get_custom_field_value_text(custom_fields.key(:homePhone)) if custom_fields['home phone number']
    data[custom_fields['federal marital status']] = user.get_custom_field_value_text(custom_fields.key(:maritalStatus)) if custom_fields['federal marital status']
    data[custom_fields['gender']] = user.get_custom_field_value_text(custom_fields.key(:gender)) if custom_fields['gender']
    data[custom_fields['middle name']] = user.get_custom_field_value_text(custom_fields.key(:middleName)) if custom_fields['middle name']

    data.merge!(map_address_field(custom_fields.key(:homeAddress), address_sub_custom_fields)) if custom_fields['home address']
    data.except!(nil)
  end

  def map_address_field(custom_field, sub_custom_fields)
    data = {}

    address_hash = user.get_custom_field_value_text(custom_field, true) || {}
    if address_hash.present? && address_hash.is_a?(String)
      data[sub_custom_fields[:line1]] = address_hash
    else
      data[sub_custom_fields[:line1]] = address_hash[sub_custom_fields.key(:address1)]
      data[sub_custom_fields[:line2]] = address_hash[sub_custom_fields.key(:address2)]
      data[sub_custom_fields[:city]] = address_hash[sub_custom_fields.key(:city)]
      data[sub_custom_fields[:state]] = address_hash[sub_custom_fields.key(:state)]
      data[sub_custom_fields[:zip]] = address_hash[sub_custom_fields.key(:zipcode)]
      data[sub_custom_fields[:country]] = address_hash[sub_custom_fields.key(:country)]
    end

    data
  end

  def get_single_dimension_data(field_name)
    data = {}

    if address_custom_fields.include? field_name.try(:downcase)
      data.merge!(map_address_field(field_name, address_sub_custom_fields))
    elsif custom_fields.include? field_name.try(:downcase)
      data[custom_fields[field_name.try(:downcase)]] = user.get_custom_field_value_text(field_name.try(:downcase))
    elsif user_fields.include? field_name.try(:downcase)
      data[user_fields[field_name.try(:downcase)]] = user[field_name.try(:downcase)].try(:to_s)
    end

    data
  end
end
