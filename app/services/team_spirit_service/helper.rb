class TeamSpiritService::Helper
  def code_value(field_name, key)
    return '' if key.blank?

    code_value_const = "#{field_name.gsub(/\s/, '_')}_CODES".upcase
    TeamSpiritService::ValueCodes.const_get(code_value_const)[key.downcase] || key
  end

  def can_send_data?(integration, user)
    return unless integration.present? && integration.filters.present?
    filter = integration.filters
    (apply_to_location?(filter, user) && apply_to_team?(filter, user) && apply_to_employee_type?(filter, user))
  end

  def sterlize_address_field_data(field_hash, key)
    serilize_value(field_hash["#{key}".to_sym])
  end

  def logging
    LoggingService::IntegrationLogging.new
  end

  def serilize_value(value)
    return '' unless value
    value.to_s.gsub(/,/ ,'')
  end

  def get_effective_date(user, custom_table_name)
    custom_table = user.company.custom_tables.find_by(name: custom_table_name)
    custom_field = user.company.custom_fields.find_by(name: 'Effective Date', custom_table_id: custom_table.id)
    CustomField.get_custom_field_value(custom_field, user.id)
  end

  def get_manager(user, field_name)
    return unless user.manager&.present?

    user.manager.get_custom_field_value_text(field_name)
  end

  private

  def apply_to_location?(filter, user)
    location_ids = filter['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filter, user)
    team_ids = filter['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filter, user)
    employee_types = filter['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type.present? && employee_types.include?(user.employee_type))
  end
end
