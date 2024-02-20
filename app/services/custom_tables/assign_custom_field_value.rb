class CustomTables::AssignCustomFieldValue
  include IntegrationFilter
  include UserOffboardManagement
  include WebhookHandler

  delegate :send_adp_custom_table_values, 
    :send_adfs_custom_table_values, :send_onelogin_custom_table_values, 
    :send_okta_custom_table_values, to: :integration_service

	def assign_values_to_user(custom_table_user_snapshot, should_send_to_integration=true)
    return unless custom_table_user_snapshot.reload.applied? && custom_table_user_snapshot.is_applicable?

		user = custom_table_user_snapshot.user

    return unless user
    company = user.company

    begin
      params = {}
      if custom_table_user_snapshot&.custom_table&.employment_status?
        if custom_table_user_snapshot.is_terminated? && custom_table_user_snapshot.terminated_data.present?
          terminated_data = custom_table_user_snapshot.terminated_data
          params = {last_day_worked: terminated_data['last_day_worked'], termination_type: terminated_data['termination_type'], eligible_for_rehire: terminated_data['eligible_for_rehire'], termination_date: custom_table_user_snapshot.effective_date }
        elsif !user.departed? && !user.offboarding? && !user.last_month? && !user.last_week?
          params = {last_day_worked: nil, termination_type: nil, eligible_for_rehire: nil, termination_date: nil}
        end
      end

      field_names = []
      field_values = []
      old_values = []
      new_values = []
      api_field_ids = []
      field_types = []
      effective_date = nil
      effective_date = custom_table_user_snapshot.effective_date if custom_table_user_snapshot.custom_table.timeline?
      custom_table_user_snapshot.custom_snapshots.includes([:custom_field]).try(:each) do |custom_snapshot|

        if custom_snapshot.preference_field_id.present?
          case custom_snapshot.preference_field_id
          when 'dpt'
            if company.teams.where(active: true, id: custom_snapshot.custom_field_value&.to_i).present? ||
               custom_snapshot.custom_field_value.blank?
              params[:team_id] = custom_snapshot.custom_field_value.presence
            end
          when 'loc'
            if company.locations.where(active: true, id: custom_snapshot.custom_field_value&.to_i).present? ||
               custom_snapshot.custom_field_value.blank?
              params[:location_id] = custom_snapshot.custom_field_value.presence
            end
          when 'jt'
            params[:title] = custom_snapshot.custom_field_value
          when 'man'
            params[:manager_id] = custom_snapshot.custom_field_value
            params[:manager_terminate_callback] = custom_table_user_snapshot.try(:manager_terminate_callback)
          when 'st'
            params[:state] = custom_snapshot.custom_field_value if custom_table_user_snapshot.terminated_data.blank?
          when 'wp'
            params[:working_pattern_id] = custom_snapshot.custom_field_value
          end
        else
          custom_field = custom_snapshot.custom_field rescue nil
          old_value = user.get_custom_field_value_text(custom_field.name, false, nil, custom_field)
          if custom_field.present?
            if custom_field.currency?
              currency_value = custom_snapshot.custom_field_value.split('|') rescue [nil, nil]
              CustomFieldValue.set_custom_field_value(user, nil, currency_value[0], 'Currency Type', false, custom_field, false, true)
              CustomFieldValue.set_custom_field_value(user, nil, currency_value[1], 'Currency Value', false, custom_field, false, true)
            elsif custom_field.phone?
              phone_value = custom_snapshot.custom_field_value.split('|') rescue [nil, nil, nil]
              CustomFieldValue.set_custom_field_value(user, nil, phone_value[0], 'Country', false, custom_field, false, true)
              CustomFieldValue.set_custom_field_value(user, nil, phone_value[1], 'Area code', false, custom_field, false, true)
              CustomFieldValue.set_custom_field_value(user, nil, phone_value[2], 'Phone', false, custom_field, false, true)
            else
              value_text = (custom_field.mcq? || custom_field.employment_status?) ? custom_field.custom_field_options.find_by_id(custom_snapshot.custom_field_value).try(:option) : custom_snapshot.custom_field_value
              CustomFieldValue.set_custom_field_value(user, nil, value_text, nil, true, custom_field, true)
            end
            field_names.push custom_field.name
            new_value = user.get_custom_field_value_text(custom_field.name, false, nil, custom_field)
            custom_field.name == "Effective Date" ? field_values.push(effective_date.strftime('%Y-%m-%d')) : field_values.push("")
            api_field_ids << custom_field.api_field_id
            field_types << custom_field.field_type
            old_values << old_value
            new_values << new_value
          end
        end
      end
      data = {field_names: field_names, field_values: field_values, api_field_ids: api_field_ids, old_values: old_values, new_values: new_values, field_types: field_types}
      user_attributes = user.attributes
      changed_attributes = []
      params.as_json.each do |paramKey, paramValue|
        checkVal = user.attributes[paramKey].to_s if paramValue != nil
        changed_attributes << paramKey if paramValue != checkVal
      end
      user.attributes = params
      user.save!(validate: false) if params.present?
      
      terminate_user(user) if params[:termination_date].present?
      logging.create(user.company, 'Assign Values To User - Pass', {response: user.inspect, custom_snapshot: custom_table_user_snapshot.custom_snapshots.inspect, request: "#{custom_table_user_snapshot.custom_table.try(:name)} - AssignCustomFieldValue(#{user.id}:#{user.full_name}) #{custom_table_user_snapshot.custom_snapshots.inspect}"}, 'CustomTables')
      send_updates_to_integrations(user, custom_table_user_snapshot, data, params, field_names, changed_attributes, user_attributes) if should_send_to_integration
      send_updates_to_webhooks(user.company, {event_type: 'job_details_changed', attributes: user_attributes, params_data: params, data: data, ctus_name: custom_table_user_snapshot&.custom_table&.name, effective_date: effective_date })
    rescue Exception => e
      logging.create(user.company, 'Assign Values To User - Fail', {custom_snapshot: custom_table_user_snapshot.custom_snapshots.inspect, request: "#{custom_table_user_snapshot.custom_table.try(:name)} - AssignCustomFieldValue(#{user.id}:#{user.full_name}) #{custom_table_user_snapshot.custom_snapshots.inspect}", error: e.message}, 'CustomTables') 
    end
	end

  private

  def integration_service
    IntegrationsService::SendUpdatesToIntegrations.new
  end

  def logging
    @logging ||= LoggingService::GeneralLogging.new
  end

  def send_updates_to_integrations(user, custom_table_user_snapshot, data, params, field_names, changed_attributes, tmp_user)
    send_updates_to_adp_us(user, custom_table_user_snapshot) if user.company.integration_types.include?('adp_wfn_us')
    send_updates_to_adfs(user, custom_table_user_snapshot) if user.company.provisioning_integration_type == 'adfs_productivity'
    send_updates_to_onelogin(user, custom_table_user_snapshot, changed_attributes) if user.company.authentication_type == 'one_login'
    send_updates_to_okta(user, custom_table_user_snapshot) if user.company.authentication_type == 'okta'

    custom_table = custom_table_user_snapshot.custom_table

    options = { is_custom_table: true, role_information: custom_table.role_information?, employment_status: custom_table.employment_status?, 
      compensation: custom_table.compensation?, tmp_user: tmp_user, custom_table: custom_table, params: params }

    ::IntegrationsService::UserIntegrationOperationsService.new(user, [ 'lessonly', 'deputy', 'fifteen_five', 'peakon', 'trinet', 'gusto', 'lattice', 'paychex', 'kallidus_learn', 'paylocity', 'namely', 'xero', 'workday'], [], options ).perform('update')
  end

  def send_updates_to_adp_us(user, custom_table_user_snapshot)
    if user.adp_wfn_us_id.present?
      send_adp_custom_table_values(user, custom_table_user_snapshot)
    end
  end

  def send_updates_to_adfs(user, custom_table_user_snapshot)
    if user.active_directory_object_id.present? && (custom_table_user_snapshot.custom_table.employment_status? || custom_table_user_snapshot.custom_table.role_information?)
      send_adfs_custom_table_values(user, custom_table_user_snapshot)
    end
  end

  def send_updates_to_onelogin(user, custom_table_user_snapshot, changed_attributes)
    if user.one_login_id.present? && custom_table_user_snapshot.custom_table.present? && (custom_table_user_snapshot.custom_table.employment_status? || custom_table_user_snapshot.custom_table.role_information?)
      send_onelogin_custom_table_values(user, custom_table_user_snapshot, changed_attributes)
    end
  end

  def send_updates_to_okta(user, custom_table_user_snapshot)
    if user.okta_id.present? && (custom_table_user_snapshot.custom_table.employment_status? || custom_table_user_snapshot.custom_table.role_information?)
      send_okta_custom_table_values(user, custom_table_user_snapshot)
    end
  end
end
 