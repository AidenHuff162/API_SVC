class IntegrationsService::SendUpdatesToIntegrations

  def send_adp_custom_table_values(user, custom_table_user_snapshot)
    SendUpdatedEmployeeToAdpWorkforceNowJob.perform_later(user.id, 'Pay Rate', nil, user.title) if custom_table_user_snapshot&.custom_table&.compensation?
    SendUpdatedEmployeeToAdpWorkforceNowJob.perform_later(user.id, 'Manager Id', nil, nil) if custom_table_user_snapshot&.custom_table&.role_information?
  end
  
  def send_adfs_custom_table_values(user, custom_table_user_snapshot)
    if custom_table_user_snapshot.present? && custom_table_user_snapshot.custom_table.present?
      if custom_table_user_snapshot.custom_table.role_information?
        attributes = ['location', 'team', 'title']
      elsif custom_table_user_snapshot.custom_table.employment_status?
        attributes = ['state']
      end

      ::SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.perform_async(user.id, attributes) if attributes.present?
    end
  end

  def send_onelogin_custom_table_values(user, custom_table_user_snapshot, changed_attributes)
    if custom_table_user_snapshot.present? && custom_table_user_snapshot.custom_table.present?
      attributes = []
      req_attributes = []
      if custom_table_user_snapshot.custom_table.role_information?
        attributes = ['department', 'title', 'location_id', 'manager_id']
        changed_attributes.each do |attribute|
          req_attributes << attribute if attributes.include?(attribute)
          req_attributes << 'department' if attribute=='team_id'
        end
      elsif custom_table_user_snapshot.custom_table.employment_status?
        req_attributes = ['employment status']
      end
      ::SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob.set(wait: 30.seconds).perform_later(user.id, req_attributes) if req_attributes.present?
    end
  end

  def send_okta_custom_table_values(user, custom_table_user_snapshot)
    if custom_table_user_snapshot.present? && custom_table_user_snapshot.custom_table.present?
      Okta::UpdateEmployeeInOktaJob.perform_in(30.seconds, user.id)
    end
  end
end
