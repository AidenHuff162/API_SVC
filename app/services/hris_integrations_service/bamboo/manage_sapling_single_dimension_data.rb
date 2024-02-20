class HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData
  attr_reader :company, :bamboo_data, :custom_fields, :sub_custom_fields, :countries

  def initialize(company)
    @company = company
    @countries = Country.all.pluck(:name)
    @custom_fields = {
      dateOfBirth: 'Date Of Birth',
      ssn: 'Social Security Number',
      ethnicity: 'Race/Ethnicity',
      mobilePhone: 'Mobile Phone Number',
      homePhone: 'Home Phone Number',
      maritalStatus: 'Federal Marital Status',
      gender: 'Gender',
      middleName: 'Middle Name',
      homeAddress: 'Home Address',
      employmentStatus: 'Employment Status'
    }
    @sub_custom_fields = {
      address1: 'Line 1',
      address2: 'Line 2',
      city: 'City',
      zipcode: 'Zip',
      state: 'State',
      country: 'Country'
    }
  end

  def initialize_bamboo_data(bamboo_data = {})
    @bamboo_data = bamboo_data
  end

  def prepare_user_data(is_user_not_exists = false, is_user_terminated = false)
    data = {}

    # Don't set location, department and title if null on bamboo
    data[:first_name] = bamboo_data['firstName']
    data[:last_name] = bamboo_data['lastName']
    data[:email] = bamboo_data['workEmail']
    data[:personal_email] = bamboo_data['homeEmail']
    data[:start_date] = bamboo_data['hireDate'] ? bamboo_data['hireDate'] : Date.parse('1-1-2016')
    data[:title] = bamboo_data['jobTitle'] if bamboo_data['jobTitle'].present?
    data[:last_changed] = bamboo_data['lastChanged']
    data[:preferred_name] = bamboo_data['nickname']
    data[:bamboo_id] = bamboo_data['id']
    data[:updated_from] = 'integration'
    data[:updating_integration] = company.integration_instances.find_by(api_identifier: 'bamboo_hr', state: :active)

    # set user provider, uid and state on user creation
    if is_user_not_exists.present?
      data[:uid] = data[:email] || data[:personal_email]
      data[:provider] = data[:email] ? 'email' : 'personal_email'
      data[:state] = 'active'
      data[:current_stage] = User.current_stages[:registered]
      data[:created_by_source] = User.created_by_sources[:bamboo]
    end

    # Set state to off-boarding if termination date is of future on bamboo
    if bamboo_data['terminationDate'].present? && bamboo_data['terminationDate'] != "0000-00-00"
      date = Date.today <= Date.parse(bamboo_data['terminationDate']) rescue nil
      if date.present?
        data[:current_stage] = User.current_stages[:offboarding]
        data[:termination_date] = bamboo_data['terminationDate']
      end
    end

    # Set state to off-boarded if termination state and status is terminated or inactive on bamboo
    if is_user_terminated.present?
      data[:state] = 'inactive'
      data[:current_stage] = User.current_stages[:departed]
      data[:termination_date] = bamboo_data['employmentHistoryStatus'].try(:downcase) != 'terminated' && bamboo_data['status'].try(:downcase) == 'inactive' ? bamboo_data['lastChanged'] : bamboo_data['terminationDate']
      data[:location_id] = nil
      data[:team_id] = nil
      data[:manager_id] = nil
    else
      data[:location_id] = map_location_id if map_location_id.present?
      data[:team_id] = map_department_id if map_department_id.present?
      data[:manager_id] = map_manager_id if map_manager_id.present?
    end

    data
  end

  def manage_profile_photo(user)
    photo = HrisIntegrationsService::Bamboo::Photo.new(company)
    return if !photo.bamboo_api_initialized?

    if bamboo_data['photoUploaded'].present?

      photo_path = photo.fetch(user.bamboo_id)
      return if !photo_path.present?

      profile_image = user.profile_image || user.build_profile_image
      profile_image.file.store!(File.open(photo_path))
      profile_image.save!
      History.create_history({
        company: company,
        user_id: user.id,
        description: I18n.t('history_notifications.profile.others_updated', full_name: 'Bamboo',field_name: 'Profile Picture',first_name: user.first_name, last_name: user.last_name)
    })
    elsif bamboo_data['photoUrl'] == "https://#{photo.bamboo_api.subdomain}.bamboohr.com/images/photo_placeholder.gif" && user.profile_image.present?
      user.profile_image.remove_file!
      user.profile_image.destroy!
    end
  end

  def manage_custom_fields(user)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:employmentStatus], map_employment_status)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:dateOfBirth], bamboo_data['dateOfBirth'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:ssn], bamboo_data['ssn'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:ethnicity], bamboo_data['ethnicity'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:mobilePhone], bamboo_data['mobilePhone'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:homePhone], bamboo_data['homePhone'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:maritalStatus], bamboo_data['maritalStatus'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:gender], bamboo_data['gender'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:middleName], bamboo_data['middleName'])

    CustomFieldValue.set_custom_field_value(user, custom_fields[:homeAddress], bamboo_data['address1'], sub_custom_fields[:address1], false)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:homeAddress], bamboo_data['address2'], sub_custom_fields[:address2], false)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:homeAddress], bamboo_data['city'], sub_custom_fields[:city], false)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:homeAddress], bamboo_data['zipcode'], sub_custom_fields[:zipcode], false)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:homeAddress], bamboo_data['state'], sub_custom_fields[:state], false)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:homeAddress], map_country(bamboo_data['country']), sub_custom_fields[:country], false)
  end

  def manage_custom_groups(user)
    # Don't set group if group value is invalid
    custom_groups = company.custom_fields.where("integration_group > ?", CustomField.integration_groups[:no_integration])
    custom_groups.try(:each) do |custom_group|
      data = bamboo_data[custom_group.mapping_key.downcase] rescue nil
      CustomFieldValue.set_custom_field_value(user, custom_group.name, data) if data.present?
    end
  end

  private
  def map_employment_status
    CustomFieldOption.joins(:custom_field).where(custom_fields: {field_type: CustomField.field_types[:employment_status], company_id: company.id}).where("option ILIKE ?", bamboo_data['employmentHistoryStatus']&.strip&.humanize&.titleize).take&.option
  end

  def map_country(country)
    index = countries.collect(&:downcase).index(country.downcase) rescue nil
    index.present? ? countries[index] : 'Other'
  end

  def map_location_id
    return if company.location_mapping_key.blank?
    company.locations.where('name ILIKE ?', bamboo_data[company.location_mapping_key.downcase]).first.try(:id)
  end

  def map_department_id
    return if company.department_mapping_key.blank?
    company.teams.where('name ILIKE ?', bamboo_data[company.department_mapping_key.downcase]).first.try(:id)
  end

  def map_manager_id
    bamboo_data['supervisorEId'].present? ? company.users.where(bamboo_id: bamboo_data['supervisorEId']).first.try(:id) : nil
  end
end
