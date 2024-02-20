class HrisIntegrationsService::Bamboo::AmountFieldValueMapping
  
  def initialize(user)
    @user = user
  end

  def fetch_custom_field_value(field_name, exclude_zero = false)
    custom_field_value = @user.get_custom_field_value_text(field_name, true)
    if custom_field_value.class.to_s == 'Hash' && exclude_zero.present?
      return custom_field_value[:currency_value].present? && custom_field_value[:currency_value] != "0" ? "#{custom_field_value[:currency_value]} - #{custom_field_value[:currency_type]}" : nil
    elsif custom_field_value.class.to_s == 'Hash'
      return custom_field_value[:currency_value].present? ? "#{custom_field_value[:currency_value]} - #{custom_field_value[:currency_type]}" : nil
    else
      return custom_field_value.present? ? custom_field_value : nil
    end
  end
end