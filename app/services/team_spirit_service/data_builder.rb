class TeamSpiritService::DataBuilder

  attr_reader :parameter_mappings, :values
  delegate :sterlize_address_field_data, :get_custom_field_value_text,  :code_value, :logging, :serilize_value, :get_effective_date, :get_manager, to: :helper_service

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
    @values = []
  end

  def build_csv_data(user, integration)
    begin
      @parameter_mappings.each do |key, value|
        value = fetch_data(value, user, integration)
        value = value.present? ? value : nil

        if value.is_a?(Array)
          values.concat(value)
        elsif value.nil? || value.is_a?(String)
          values.push(value)
        end
      end
      values
    rescue Exception => e
      logging.create(user.company, 'TeamSpirit', "Fetch USER:#{user.id} - Failure", nil, { error: e.to_s }.to_json, 500)
      -1
    end
  end

  private
  def fetch_data(meta, user, integration)
    return unless user.present? && meta.present?
    field_name = meta[:name].to_s.downcase
    case field_name
    when 'line1', 'line2', 'city', 'state', 'zip'
      home_address = user.get_custom_field_value_text('Home Address', true)
      sterlize_address_field_data(home_address, field_name)
    when 'department'
      code_value(field_name, user.team&.name)
    when 'venue name'
      code_value('locations', user.location&.name)
    when 'nationality'
      value = get_value(user, meta, field_name)
      code_value(field_name, value)
    when 'job title'
      code_value(field_name , user.title)
    when 'holiday profile', 'holiday entitlement profile'
      value = user.get_custom_field_value_text(field_name)
      code_value('holiday_profile', value)
    when 'start date', 'continuous service start date', 'termination date', 'date of birth', 'expiry date'
      serilize_value(format_date(get_value(user, meta, field_name)))
    when 'effective date'
      serilize_value(format_date(get_effective_date(user, 'Compensation')))
    when 'pay rate'
      serilize_value(get_value(user, meta, field_name)).tr('^0-9', '')  
    when 'manager'
      serilize_value(get_manager(user, 'existing employee code'))
    else
      serilize_value(get_value(user, meta, field_name))
    end
  end

  def format_date(value)
    return unless value.present?
    value.to_date.strftime('%d/%m/%Y')
  end

  def get_value(user, meta, field_name)
    if meta[:is_custom].blank?
      user.attributes[field_name.tr(' ', '_')]
    else
      user.get_custom_field_value_text(field_name)
    end
  end

  def helper_service
    TeamSpiritService::Helper.new
  end
end
