class HrisIntegrationsService::Namely::DataBuilder
  attr_reader :parameter_mappings, :company, :user, :namely, :namely_credentials

  delegate  :find_team, :find_location, :is_namely_credentials?, :send_notifications, :get_career_level_code, :get_gender_code, :get_namely_profile_image_id,
            :get_namely_job_title, :get_custom_field_value_for_namely_group_type, :get_federal_marital_status_code, :get_employee_type,
            :get_federal_withholding_additional_type_code, :get_type_of_account_code, :get_home_address, :log,  to: :helper_service

  def initialize(parameter_mappings, company, integration, user, namely)
    @parameter_mappings = parameter_mappings
    @company = company
    @namely_credentials = integration
    @user = user
    @namely = namely
  end

  def build_create_profile_data
    data = {
      user_status: "active",
    }
    build_company_params()
    @parameter_mappings.each do |key, value|
      if value[:exclude_in_create].blank? && ["", nil].exclude?(value[:name])
        fetch_data('create', key, value, data)
      end
    end 
    handle_custom_groups(data)
    data&.reject { |k,v| v.blank? }
  end

   def build_update_profile_data(attributes)
    data = {}
    build_company_params()
    @parameter_mappings.each do |key, value|
      if value[:exclude_in_update].blank? && attributes.include?(value[:name])
        fetch_data('update', key, value, data)
      end
    end 
    handle_custom_groups(data, attributes)
    data&.reject { |k,v| v.blank? }
  end
  
  def fetch_data(action, key, value, data)
    return if @company.domain == 'cruise.saplingapp.io' && value[:source].present? && @user.created_by_source == value[:source] 
    home_address = get_home_address('Home Address', @user, @namely)
    if value[:is_profile_field].present?
      data["#{key}"] = @user.profile["#{value[:name]}"] 
    elsif key == :email
      data["#{key}"] = @user["#{value[:name]}"] || @user.personal_email
    elsif key == :job_title
      data["#{key}"] = get_namely_job_title(@user.title, @namely)
    elsif key == :reports_to
      data["#{key}"] = @user.manager.namely_id if @user.manager.present? && @user.manager.namely_id.present?
    elsif key == :location
      if action == 'update'
        location = find_location(@user.location_id, @company)
      else
        location = @user.location
      end
      data["#{location.namely_group_type}"] = location.name if location.present? && location.namely_group_type.present?
    elsif key == :team
      if action == 'update'
        team = find_team(@user.team_id, @company)
      else
        team = @user.team
      end
      data["#{team.namely_group_type}"] = team.name if team.present? && team.namely_group_type.present?
    elsif key == :image
        data["#{key}"] = get_namely_profile_image_id(@user, @company, @namely_credentials) rescue nil
    elsif value[:is_custom]
      if value[:parent_hash].present? && home_address && home_address[:country] && home_address[:state]
        data["#{key}"] = home_address[:"#{value[:name]}"]
      elsif key == :employee_type
        employment_status = @user.get_custom_field_value_text(value[:name])
        if @user.company.domain == "kayak.saplingapp.io" 
          data[:time_type_ft_pt] = get_employee_type(employment_status, @user)
        else
          data["#{key}"] = get_employee_type(employment_status, @user)
        end
      elsif key == :marital_status || key == :federal_filing_marital_status || key == :state_filing_marital_status
        data["#{key}"] = get_federal_marital_status_code(@user.get_custom_field_value_text("#{value[:name]}")) rescue nil
      elsif key == :federal_withholding_additional_type
        data["#{key}"] = get_federal_withholding_additional_type_code(@user.get_custom_field_value_text("#{value[:name]}")) rescue nil
      elsif key == :type_of_account
        data["#{key}"] = get_type_of_account_code(@user.get_custom_field_value_text("#{value[:name]}")) rescue nil
      elsif key == :career_level
        data["#{key}"] = get_career_level_code(@user.get_custom_field_value_text("#{value[:name]}")) rescue nil
      elsif key == :gender
        data["#{key}"] = get_gender_code(@user.get_custom_field_value_text("#{value[:name]}")) rescue nil
      else
        data["#{key}"] = @user.get_custom_field_value_text("#{value[:name]}") || ''
      end
    else
      data["#{key}"] = @user["#{value[:name]}"] || ''
    end
    data
  end

  def helper_service
    HrisIntegrationsService::Namely::Helper.new
  end

  def build_company_params
    method_name = "push_users_for_" + @company.domain.downcase.gsub('.', '_') rescue nil
    push_parameters = ::HrisIntegrationsService::Namely::ParamsMapper.new
    additional_company_fields = push_parameters.public_send(method_name) if push_parameters.respond_to? method_name
    @parameter_mappings.merge!(additional_company_fields) if additional_company_fields.present?
  end

  def handle_custom_groups(data, field_names = nil)
    custom_groups = @company.custom_fields.where(integration_group: CustomField.integration_groups[:namely] )
    custom_groups=  custom_groups.where('name ILIKE ANY (array[?])', field_names) if custom_groups.present? && field_names.present?
    custom_groups.try(:each) do |group|
      value_option = get_custom_field_value_for_namely_group_type(group.name, @company, @user)
      data.merge!({"#{value_option.namely_group_type}": value_option.option}) if value_option.present?
    end
  end
end
