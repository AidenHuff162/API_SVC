class CustomSections::AssignRequestedFieldValue
  include WebhookHandler

  def assign_values_to_user(custom_section_approval)
    return unless custom_section_approval.approved?

    user_id = custom_section_approval.user_id
    user = User.find_by(id: user_id)
    requester = User.find_by(id: custom_section_approval.requester_id)
    company = custom_section_approval&.custom_section&.company

    return unless user
    tempUser = User.find_by(id: user.id)

    begin
      params = {}
      profile_params = {}

      field_names = []
      field_values = []
      old_values = []
      new_values = []
      api_field_ids = []
      field_types = []

      custom_section_approval.requested_fields.includes([:custom_field]).try(:each) do |requested_field|

        if requested_field.preference_field_id.present?
          case requested_field.preference_field_id
          when 'first_name', 'last_name', 'preferred_name', 'personal_email', 'start_date'
            params[requested_field.preference_field_id.to_sym] = requested_field.custom_field_value
          when 'company_email'
            params[:email] = requested_field.custom_field_value
          when 'buddy'
            params[:buddy_id] = requested_field.custom_field_value
          when 'department'
            params[:team_id] = requested_field.custom_field_value
          when 'manager'
            params[:manager_id] = requested_field.custom_field_value
          when 'location'
            params[:location_id] = requested_field.custom_field_value
          when 'working_pattern'
            params[:working_pattern_id] = requested_field.custom_field_value
          when 'job_title'
            params[:title] = requested_field.custom_field_value
          when 'status'
            params[:state] = requested_field.custom_field_value
          when 'paylocityid'
            params[:paylocity_id] = requested_field.custom_field_value
          when 'trinetid'
            params[:trinet_id] = requested_field.custom_field_value
          when 'access_permission'
            params[:user_role_id] = requested_field.custom_field_value
          when 'about'
            profile_params[:about_you] = requested_field.custom_field_value
          when 'twitter', 'linkedin', 'github', 'facebook'
            profile_params[requested_field.preference_field_id.to_sym] = requested_field.custom_field_value
          end
        else
          custom_field = requested_field.custom_field rescue nil
          old_value = tempUser.get_custom_field_value_text(custom_field&.name, false, nil, custom_field)

          if custom_field.present?
            if custom_field.address?
              assign_sub_custom_field_values(requested_field, ['Line 1', 'Line 2', 'City', 'State', 'Zip', 'Country'], user, custom_field)
            elsif custom_field.currency?
              assign_sub_custom_field_values(requested_field, ['Currency Type', 'Currency Value'], user, custom_field)
            elsif custom_field.phone?
              assign_sub_custom_field_values(requested_field, ['Country', 'Area code', 'Phone'], user, custom_field)
            elsif custom_field.tax?
              assign_sub_custom_field_values(requested_field, ['Tax Type', 'Tax Value'], user, custom_field)
            else
              value_text = nil
              if custom_field.mcq? || custom_field.employment_status?
                value_text = custom_field.custom_field_options.find_by_id(requested_field['custom_field_value']['custom_field_option_id']).try(:option)
              elsif custom_field.coworker?
                value_text = requested_field['custom_field_value']['coworker_id']
              elsif custom_field.multi_select?
                value_text = requested_field['custom_field_value']['checkbox_values']
              elsif custom_field.national_identifier?
                assign_sub_custom_field_values(requested_field, ['ID Country', 'ID Type', 'ID Number'], user, custom_field)
              else
                value_text = requested_field['custom_field_value']['value_text']
              end
              CustomFieldValue.set_custom_field_value(user, nil, value_text, nil, true, custom_field, true)
              user.update_column(:fields_last_modified_at, Date.today)
            end
            
            new_value = user.get_custom_field_value_text(custom_field&.name, false, nil, custom_field)
            send_data_to_integrations_for_custom_field_value(custom_field, user, requester, company, new_value, old_value)
            field_names << requested_field.custom_field.name
          end
        end
      end
      send_updates_to_workday(user, field_names) if user.workday_id.present? && field_names.present?

      if profile_params.present?
        tempProfile = tempUser.profile
        
        user.profile.attributes = profile_params
        user.profile.save!

        send_data_to_integrations_for_profile(tempProfile, user.profile.attributes.with_indifferent_access, company, tempUser, requester) 
      end

      if params.present?
        user.attributes = params
        user.fields_last_modified_at = Date.today
        user.save!

        user.reload
        user_params = user.attributes
        if params[:manager_id]
          user_params['manager'] = {id: params[:manager_id]}
          user.manager_email()
        end
        user_params['buddy'] = {id: params[:buddy_id]} if params[:buddy_id]
        if params[:user_role_id]
          role_name = user.company.user_roles.find_by(id: params[:user_role_id]).try(:name)
          user_params['user_role_name'] = role_name
        end
        user_params['start_date'] = user_params['start_date'].to_s

        send_data_to_integrations_for_user(tempUser, user_params.with_indifferent_access, company, requester)
      end

      logging.create(user.company, 'Assign Values To User - Pass', {response: user.inspect, custom_section_approval: custom_section_approval.requested_fields.inspect, request: "#{custom_section_approval.custom_section.try(:name)} - AssignCustomFieldValue(#{user.id}:#{user.full_name}) #{custom_section_approval.requested_fields.inspect}"}, 'CustomSectionApproval')
    rescue Exception => e
      logging.create(user.company, 'Assign Values To User - Fail', {custom_section_approval: custom_section_approval.requested_fields.inspect, request: "#{custom_section_approval.custom_section.try(:name)} - AssignCustomFieldValue(#{user.id}:#{user.full_name}) #{custom_section_approval.requested_fields.inspect}", error: e.message}, 'CustomSectionApproval') 
    end
  end

  def logging
    @logging ||= LoggingService::GeneralLogging.new
  end

  def assign_sub_custom_field_values(requested_field, field_format, user, custom_field)
    custom_field_value = nil
    field_format.each do |key|
      sb_field = requested_field['custom_field_value']['sub_custom_fields'].select { |f| f['name'] == key }&.first
      custom_field_value = (sb_field.key?('custom_field_value') && !sb_field['custom_field_value'].nil? && sb_field['custom_field_value'].key?('value_text') ? sb_field['custom_field_value']['value_text'] : nil)
      CustomFieldValue.set_custom_field_value(user, nil, custom_field_value, key.to_s, false, custom_field, false, true)
    end
  end

  def send_data_to_integrations_for_custom_field_value(custom_field, tempUser, requester, company, new_value, old_value)
    field_name = custom_field&.name

    if custom_field.section == "additional_fields" && tempUser.state == "active"
      PushEventJob.perform_later('additional-fields-updated', requester, {
        employee_name: tempUser[:first_name] + ' ' + tempUser[:last_name],
        employee_email: tempUser[:email],
        field_name: field_name,
        value_text: new_value,
        company: company[:name]
      })
    end

    begin
      if new_value.present?
        SlackNotificationJob.perform_later(company.id, {
          username: tempUser.full_name,
          text: I18n.t('slack_notifications.custom_field.updated', field_name: field_name, first_name: tempUser[:first_name], last_name: tempUser[:last_name])
        })
      end

      ::CustomFieldValueToIntegrationsManagment.new.send_custom_field_updates_to_integrations(tempUser, field_name, custom_field, company)
      send_updates_to_webhooks(company, {event_type: 'custom_field', custom_field_id: custom_field.id, old_value: old_value, new_value: new_value, user_id: tempUser.id })
    
    rescue Exception => e
      p e
    end

    if requester.id == tempUser.id
      description = I18n.t('history_notifications.custom_field.self_updated', user_first_name: tempUser.first_name, user_last_name: tempUser.last_name , field_name: field_name)
    else
      description = I18n.t('history_notifications.custom_field.updated',user_first_name: requester.first_name, user_last_name: requester.last_name, field_name: field_name, employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
    end

    if field_name
      CreateHistoryLogJob.perform_later(requester.id, description, tempUser.id, field_name)
    end
  end

  def send_data_to_integrations_for_user(tempUser, params, company, requester)
    slack_message = nil
    history_description = nil
    
    if params[:state] == "active" &&
       (tempUser.personal_email != params[:personal_email] ||
        tempUser.first_name != params[:first_name] ||
        tempUser.last_name != params[:last_name])
      PushEventJob.perform_later('personal-information-updated', requester, {
        employee_id: params[:id],
        employee_name: "#{params[:first_name]} #{params[:last_name]}",
        employee_email: params[:email],
        company: company[:name]
      })
      slack_message = I18n.t("slack_notifications.user.updated.personal_information", first_name: params[:first_name], last_name: params[:last_name])
    elsif params[:state] == "active" && tempUser[:manager_id] != params[:manager_id]
      PushEventJob.perform_later('manager-updated', requester, {
        employee_id: params[:id],
        employee_name: "#{params[:first_name]} #{params[:last_name]}",
        employee_email: params[:email],
        manager: params[:manager_id],
        company: company[:name]
      })
      slack_message = I18n.t("slack_notifications.user.updated.manager", first_name: params[:first_name], last_name: params[:last_name])
    elsif params[:state] == "active" &&
       (tempUser.location_id != params[:location_id] ||
        tempUser.title != params[:title])
      PushEventJob.perform_later('contact-details-updated', requester, {
        employee_id: params[:id],
        employee_name: "#{params[:first_name]} #{params[:last_name]}",
        employee_email: params[:email],
        title: params[:title],
        company: company[:name]
      })
      slack_message = I18n.t("slack_notifications.user.updated.contact_details", first_name: params[:first_name], last_name: params[:last_name])
    elsif params[:id].present? && params[:first_name].present? && params[:last_name].present? && params[:email].present?
      PushEventJob.perform_later('employee-updated', requester, {
        employee_id: params[:id],
        employee_name: "#{params[:first_name]} #{params[:last_name]}",
        employee_email: params[:email],
        company: company[:name]
      })
      slack_message = I18n.t("slack_notifications.user.updated.profile", first_name: params[:first_name], last_name: params[:last_name])
    end
    SlackNotificationJob.perform_later(company.id, {
      username: requester.full_name,
      text: slack_message
    }) if slack_message.present?

    Interactions::HistoryLog::CustomFieldHistoryLog.log(tempUser,params,requester) if params["state"] == "active"
    
    begin
      ::UserDataToIntegrationsManagment.new.send_user_updates_to_integrations(tempUser, params, company)
      send_updates_to_webhooks(company, {event_type: 'profile_changed', attributes: tempUser.attributes, params_data: params, profile_update: false})
    rescue Exception => e
    end
  end

  def send_data_to_integrations_for_profile(tempProfile, profile_params, company, tempUser, requester)
    return unless company.present?

    if requester.present? && tempUser.present? && tempUser.state == "active" && (tempProfile.about_you != profile_params[:about_you] ||
       tempProfile.facebook != profile_params[:facebook] ||
       tempProfile.twitter != profile_params[:twitter] ||
       tempProfile.linkedin != profile_params[:linkedin] ||
       tempProfile.github != profile_params[:github] )
      PushEventJob.perform_later('profile-updated', requester, {
        employee_id: tempUser.id,
        employee_name: tempUser.first_name + ' ' + tempUser.last_name,
        employee_email: tempUser.email,
        about_employee: profile_params[:about_you]
      })
    end

    field_name = [] 
    if tempUser.present? && tempUser.state == "active" 
      if tempProfile.about_you != profile_params[:about_you]
        field_name << "About You"
      end
      if  tempProfile.facebook != profile_params[:facebook]
        field_name << "FaceBook"
      end
      if tempProfile.twitter != profile_params[:twitter] 
        field_name << "Twitter"
      end
      if  tempProfile.linkedin != profile_params[:linkedin]
        field_name << "Linkedin"
      end
      if tempProfile.github != profile_params[:github]
        field_name << "Github"
      end
    end

    begin
      history_description = nil
      slack_description = nil

      field_name.try(:each) do |field|

        if tempUser.present? && tempUser.id == requester.id 
          history_description = I18n.t("history_notifications.profile.own_updated", first_name: tempUser.first_name, last_name: tempUser.last_name,field_name: field)
          slack_description = I18n.t("slack_notifications.profile.own_updated", first_name: tempUser.first_name, last_name: tempUser.last_name)
        elsif tempUser.present?
          history_description = I18n.t("history_notifications.profile.others_updated", full_name: requester.full_name,field_name: field, first_name: tempUser.first_name, last_name: tempUser.last_name)
          slack_description = I18n.t("slack_notifications.profile.others_updated", full_name: requester.full_name, first_name: tempUser.first_name, last_name: tempUser.last_name)
        end
        SlackNotificationJob.perform_later(company.id, {
          username: requester.full_name,
          text: slack_description
        }) if slack_description.present?
        History.create_history({
          company: company,
          user_id: requester.id,
          description: history_description,
          attached_users: [requester.id, tempUser.id]
        }) if history_description.present?

      end
    rescue Exception => e
    end

    attributes = tempProfile.attributes
    attributes["id"] = tempUser.id
    send_updates_to_webhooks(company, {event_type: 'profile_changed', attributes: attributes, params_data: profile_params, profile_update: true})
  end

  def send_updates_to_workday(user, field_names)
    HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob.perform_later(user.id, field_names)
  end

end
 