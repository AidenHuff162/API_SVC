module HrisIntegrationsService::Workday::Exceptions

  def validate_creds_presence!(integration)
    credentials = integration.integration_credentials
    ['User Name', 'Password'].map do |cred|
      validate_presence!(cred, credentials.by_name(cred).take&.value)
    end
  end

  def validate_presence!(value_name, value)
    raise "#{value_name} cannot be blank!" if value.blank?
  end

  def validate_worker_subtype!(user)
    helper = HrisIntegrationsService::Workday::Helper.new
    worker_subtype_filters = helper.get_worker_subtype_filters(user.company, user.workday_id_type)
    return if worker_subtype_filters.include?(user.workday_worker_subtype)

    raise "#{user.workday_worker_subtype} is not allowed to sync."
  end

end
