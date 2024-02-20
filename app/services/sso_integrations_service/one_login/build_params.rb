class SsoIntegrationsService::OneLogin::BuildParams
  attr_reader :user, :integration, :company

  def initialize(user, one_login_integration)
    @user = user
    @company = user.company
    @integration = one_login_integration
  end

  def create_params
    data = {}

    data[:firstname] = user.first_name
    data[:firstname] = (user.preferred_name || user.first_name) if integration.sync_preferred_name
    data[:lastname] = user.last_name
    data[:email] = user.email || user.personal_email
    data[:username] = (data[:firstname].try(:downcase).try(:to_s) + '.' + user.last_name.to_s).gsub(/\s+/, "")
    data[:member_of] = user.team.try(:name)
    data[:distinguished_name] = user.preferred_name if !company.one_login_updates_feature_flag 
    data[:title] = user.title
    data[:company] = company.name
    data[:phone] = user.get_custom_field_value_text('Mobile Phone Number')
    data[:department] = (company.department == 'Department') ? user.team.try(:name) : user.get_custom_field_value_text('Department')
    data[:manager_user_id] = user.manager&.one_login_id if company.one_login_updates_feature_flag

    data
  end

  def build_custom_attributes
    data = {}
    data[:custom_attributes] = {
      location: user.location_name
    }

    if company.subdomain.eql?('compass')    
      data[:custom_attributes][:market]    = user.get_custom_field_value_text('Market')
      data[:custom_attributes][:submarket] = user.get_custom_field_value_text('Sub-Market')
      data[:custom_attributes][:office]    = user.get_custom_field_value_text('Office Location')
    end
    data
  end

  def update_params(field_name, data)
    return unless field_name.present?

    if users_params.include? field_name.try(:downcase)
      data[users_params[field_name.try(:downcase)]] = user[field_name.try(:downcase)].try(:to_s) unless (field_name.try(:downcase) == 'preferred_name' || (field_name.try(:downcase) == 'first_name' && integration.sync_preferred_name)) && company.one_login_updates_feature_flag
      if ['preferred_name'].include?(field_name.try(:downcase)) && integration.sync_preferred_name
        data[:firstname] = user['preferred_name'] || user['first_name'].try(:to_s)
      end
    elsif custom_params.include? field_name.try(:downcase)
      data[custom_params[field_name.try(:downcase)]] = user.get_custom_field_value_text(field_name.try(:downcase))
    elsif relation_params.include? field_name.try(:downcase)
      data[relation_params[field_name.try(:downcase)]] = user.team.try(:name)  
    elsif custom_attribute_params.include? field_name.try(:downcase)
      data[:custom_attributes] = {} if data[:custom_attributes].blank?
      data[:custom_attributes][:location] = user.location&.name if field_name == 'location_id'
      build_custom_attribute(field_name, data) if field_name != 'location_id' && Rails.env.staging?
    end

    if field_name.downcase == 'department' || field_name.downcase == 'team'
      data[:department] = (company.department == 'Department') ? user.team.try(:name) : user.get_custom_field_value_text('Department')
    end

    if field_name.downcase == 'manager_id' && company.one_login_updates_feature_flag
      data[:manager_user_id] = user.manager&.one_login_id
    end

    data
  end

  private

  def users_params
    params = {
      'first_name' => :firstname,
      'last_name' => :lastname,
      'email' => :email,
      'title' => :title,
      'preferred_name' => :preferredname
    }
    params.merge!('preferred_name' => :distinguished_name) if company.one_login_updates_feature_flag
    params
  end

  def custom_params
    { 'mobile phone number' => :phone }
  end

  def relation_params
    { 'team_id' => :member_of }
  end

  def custom_attribute_params
    params = {
      'start_date' => :start_date,
      'personal_email' => :personalemail,
      'employment status' => :employee_type,
      'location_id' => :location,
    }
    params.merge!('manager_id' => :Manager) if !company.one_login_updates_feature_flag
    params
  end

  def format_date(value)
    return unless value.present?
    value.to_date.strftime('%Y-%m-%d')  
  end

  def build_custom_attribute field_name, data
    data[:custom_attributes] = {} if data[:custom_attributes].blank?

    case field_name
    when 'manager_id'
      data[:custom_attributes][:Manager] = user.manager&.full_name
    when 'employment status'
      data[:custom_attributes][:employee_type] = user.get_custom_field_value_text('Employment Status')
    when 'start_date'
      data[:custom_attributes][:start_date] = format_date(user.start_date)
    when 'personal_email'
      data[:custom_attributes][custom_attribute_params[field_name.try(:downcase)]] = user[field_name.try(:downcase)]
    end
    data
  end
end
 
