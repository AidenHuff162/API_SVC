class HrisIntegrationsService::Bamboo::ManageBambooTabularData
  attr_reader :user, :emergency_custom_fields, :job_information_fields, :employment_status_fields

  def initialize(user)
    @user = user
    @emergency_custom_fields = {
      'emergency contact name' => 'name',
      'emergency contact number' => 'homePhone',
      'emergency contact relationship' => 'relationship'
    }

    @job_information_fields = [ 'division', 'job information']
    @employment_status_fields = [ 'employment status']
  end


  def update_tabular_data
    update_emergency_contact
    update_job_information
    update_employment_status
  end

  def update_selected_tabular_data(field_name)
    if emergency_custom_fields["#{field_name.try(:downcase)}"].present?
      update_emergency_contact
    elsif job_information_fields.include? field_name.try(:downcase)
      update_job_information(true)
    elsif employment_status_fields.include? field_name.try(:downcase)
      update_employment_status(true)
    end
  end

  def emergency_contact_params
    name = user.get_custom_field_value_text(emergency_custom_fields.key('name'))
    homePhone = user.get_custom_field_value_text(emergency_custom_fields.key('homePhone'))
    relationship = user.get_custom_field_value_text(emergency_custom_fields.key('relationship'))
    mobilePhone = user.get_custom_field_value_text(emergency_custom_fields.key('mobilePhone'))

    params = "
      <field id='name'>#{name}</field>
      <field id='homePhone'>#{homePhone}</field>
      <field id='relationship'>#{relationship}</field>
      <field id='mobilePhone'>#{mobilePhone}</field>
    "

    if emergency_custom_fields.key('address')
      address = user.get_custom_field_value_text(emergency_custom_fields.key('address'), true) || {}
      params = params + "<field id='addressLine1'>#{address[:line1] || ''}</field>
        <field id='addressLine2'>#{address[:line2] || ''}</field>
        <field id='city'>#{address[:city] || ''}</field>
        <field id='zipcode'>#{address[:zip] || ''}</field>
        <field id='country'>#{address[:country]}</field>
        <field id='state'>#{address[:state]}</field>"
    end

    if emergency_custom_fields.key('email')
      email = user.get_custom_field_value_text(emergency_custom_fields.key('email'))
      params = params + "<field id='email'>#{email}</field>"
    end

    params.gsub('&', '&amp;')
  end

  def job_information_params(can_send_current_date)
    custom_field = user.company.custom_fields.find_by('name ILIKE ?', 'division')
    division = user.custom_field_values.find_by(custom_field_id: custom_field.try(:id)).custom_field_option.option rescue nil
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s

    params = "
      <field id='#{user.company.location_mapping_key.parameterize.underscore}'>#{user.location.try(:name)}</field>
      <field id='#{user.company.department_mapping_key.parameterize.underscore}'>#{user.team.present? ? user.team.name : nil}</field>
      <field id='reportsTo'>#{user.manager.try(:full_name)}</field>
      <field id='date'>#{date}</field>
      <field id='jobTitle'>#{user.title.present? ? user.title.gsub('&', '&amp;') : nil}</field>
    "

    if division.present?
      params = params + "<field id='#{custom_field.mapping_key.parameterize.underscore}'>#{division.present? ? division : nil}</field>"
    end

    params.gsub('&', '&amp;')
  end

  def employment_status_params(can_send_current_date)
    employmentHistoryStatus = user.employee_type_field_option&.option
    employmentHistoryStatus = employmentHistoryStatus&.gsub('_',' ')&.titleize if user.company.domain != 'vennbio.saplingapp.io'
    
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s

    params = "<row>
      <field id='date'>#{date}</field>
      <field id='employmentStatus'>#{employmentHistoryStatus}</field>
    </row>"

    params
  end

  private

  def update_emergency_contact
    params = emergency_contact_params
    emergency_contact = HrisIntegrationsService::Bamboo::EmergencyContact.new(user.company)
    emergency_contact.create_or_update("#{user.id}: Create/Update Emergency Contact In Bamboo (#{user.bamboo_id})", user.bamboo_id, "<row>#{params}</row>")
  end

  def update_job_information(can_send_current_date = false)
    params = job_information_params(can_send_current_date)
    job_information = HrisIntegrationsService::Bamboo::JobInformation.new(user.company)
    job_information.create_or_update("#{user.id}: Create/Update Job Information In Bamboo (#{user.bamboo_id})", user.bamboo_id, "<row>#{params}</row>")
  end

  def update_employment_status(can_send_current_date = false)
    params = employment_status_params(can_send_current_date)
    employment_status = HrisIntegrationsService::Bamboo::EmploymentStatus.new(user.company)
    employment_status.create_or_update("#{user.id}: Create/Update Employment Status In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
  end
end
