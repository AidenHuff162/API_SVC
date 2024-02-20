module WebhookEventServices
  class ParamsBuilderService
    delegate :format_date, to: :helper_service

    def build_request_params(company, event_data, webhook)
      params = { webhook_event: prepare_customer_params(company) }

      case event_data['type']
      when 'new_pending_hire'
        params[:webhook_event].merge!(prepare_pending_hire_params(company, event_data))
      when 'stage_completed', 'stage_started'
        params[:webhook_event].merge!(prepare_stage_changed_params(company, event_data))
      when 'key_date_reached'
        params[:webhook_event].merge!(prepare_key_date_reached_params(company, event_data, webhook))
      when 'profile_changed', 'job_details_changed'
        params[:webhook_event].merge!(prepare_profile_changed_params(company, event_data, webhook))
      when 'onboarding', 'offboarding'
        params[:webhook_event].merge!(user_onboarding_offboarding_params(company, event_data))
      end
      return params
    end

    def build_webhook_event_params(webhook_event)
      {
        webhook: {
          id: webhook_event.webhook.guid,
          event: webhook_event.webhook.event.titleize,
          eventID: webhook_event.event_id
        } 
      }
    end

    def prepare_customer_params(company)
      {
        customer: {
          domain: company.domain,
          companyID: company.uuid 
        }
      }
    end

    def prepare_pending_hire_params(company, event_data)
      pending_hire = company.pending_hires.with_deleted.find_by(id: event_data['pending_hire_id'])
      params = { pending_hire: { action: event_data['action'], source: 'https://www.kallidus.com' } }
      
      return params if pending_hire.blank?

      params[:pending_hire].merge!({
        personalEmail: pending_hire.personal_email,
        firstName: pending_hire.first_name,
        preferredName: pending_hire.preferred_name,
        lastName: pending_hire.last_name,
        startDate: format_date(company.get_date_format, pending_hire.start_date),
        jobTitle: pending_hire.title,
        department: pending_hire.team&.name,
        location: pending_hire.location&.name,
        status: pending_hire.state,
        employmentStatus: pending_hire.employee_type,
        pendingHireId: pending_hire.guid,
      })
      
      params
    end

    def prepare_stage_changed_params(company, event_data)
      user = company.users.with_deleted.find_by(id: event_data['triggered_for'])

      return {} if user.blank?

      params = { user: user_params(user, company)}
      params[:user].merge!({"#{event_data['type'].camelcase}": event_data['stage']})
 
      params
    end

    def prepare_key_date_reached_params(company, event_data, webhook)
      user = company.users.with_deleted.find_by(id: event_data['triggered_for'])
      return {} if user.blank?

      params = { user: user_params(user, company)}
      params[:user].merge!({keydatesReached: { date: company.time.to_date, dateType: (webhook.configurable['date_types'][0] == "all" ? event_data['date_types'] : (event_data['date_types'] & webhook.configurable['date_types']))}})
      
      params
    end

    def prepare_profile_changed_params(company, event_data, webhook)
      user = company.users.with_deleted.find_by(id: event_data['triggered_for'])
      return {} if user.blank?
      
      params =  { 
        user: {
          email: user.email,
          personalEmail: user.personal_email,
          userId: user.guid,
          fields_changed: {
            date: format_date(company.get_date_format, company.time.to_date),
            fields: get_fields_changed(company, event_data[:values_changed], webhook.extract_configurable)
          }
        }
      }

      params
    end

    def prepare_test_pending_hire_params(company, event_data)
      pending_hire = company.users.with_deleted.find_by(id: event_data['triggered_for'])
      params = { pending_hire: { action: event_data['action'], source: 'https://www.kallidus.com' } }
      
      return params if pending_hire.blank?

      params[:pending_hire].merge!({
        personalEmail: pending_hire.personal_email,
        firstName: pending_hire.first_name,
        preferredName: pending_hire.preferred_name,
        lastName: pending_hire.last_name,
        startDate: pending_hire.start_date&.to_date&.strftime('%Y-%m-%d'),
        jobTitle: pending_hire.title,
        department: pending_hire.team&.name,
        location: pending_hire.location&.name,
        status: pending_hire.state,
        employmentStatus: pending_hire.employee_type,
      })
      
      params
    end

    private
    def user_params(user, company)
      {
        email: user.email,
        personalEmail: user.personal_email,
        firstName: user.first_name,
        preferredName: user.preferred_name,
        lastName: user.last_name,
        startDate: format_date(company.get_date_format, user.start_date),
        jobTitle: user.title,
        department: user.team&.name,
        location: user.location&.name,
        status: user.state,
        employmentStatus: user.employee_type_field_option&.option,
        userId: user.guid
      }
    end

    def user_onboarding_offboarding_params(company,event_data)
      user = company.users.unscoped.find_by(id: event_data['user_id'])
      params = {
          eventType: event_data[:type],
          eventTime: Time.now,
          eventActivity: {
            activityState: event_data[:stage],
            activityInitiatedByGuid: event_data[:triggered_by]
          }
        }
      if event_data[:type] == 'onboarding'
        params.merge!({
          email: user.email,
          personalEmail: user.personal_email,
          firstName: user.first_name,
          preferredName: user.preferred_name,
          lastName: user.last_name,
          userGuid: user.guid,
          userId: user.id,
          status: user.state,
          current_stage: user.current_stage,
          startDate: format_date(company.get_date_format, user.start_date),
          accountProvision:{
            accountProvider: nil,
            accountProvisionRequest: 'No',
            accountProviderSchedule: nil,
            accountProvisionTime: nil
          }
        })
        auth_type = ['okta', 'one_login'].include? company.authentication_type
        provision_type = ['gsuite', 'adfs_productivity'].include? company.provisioning_integration_type
        params[:accountProvision].merge!({
          accountProvider: provision_type ? company.provisioning_integration_type : company.authentication_type,
          accountProvisionRequest: 'Yes',
          accountProviderSchedule: get_provision_schedule(user),
          accountProvisionTime: get_provision_time(user)
        }) if auth_type || provision_type
      else
        params.merge!({email: user.email,
        personalEmail: user.personal_email,
        firstName: user.first_name,
        preferredName: user.preferred_name,
        lastName: user.last_name,
        userGuid: user.guid,
        userId: user.id,
        status: user.state,
        current_stage: user.current_stage,
        terminationDate: user.termination_date,
        lastDayWorked: user.last_day_worked,
        terminationType: user.termination_type,
        eligibleForRehire: user.eligible_for_rehire,
        accessCutOff:{
          accessCutOffSchedule: user.remove_access_timing,
          accessCutOffTime: get_cut_off_time(user)
        }
      })
      end
      params
    end

    def get_provision_schedule(user)
      case user.send_credentials_type
      when 'on'
        'on start date'
      when 'before'
        "#{user.send_credentials_offset_before} days before start date"
      else
        user.send_credentials_type
      end
    end

    def get_provision_time(user)
      time_start, time_add, cred_type = user.start_date, user.send_credentials_time.hours, user.send_credentials_type
      begin
        if ['on', 'before', 'immediately'].include?(cred_type)
          time_start = (time_start - user.send_credentials_offset_before.days) if cred_type == 'before'
          time_add = 0 if cred_type == 'immediately'
          return (time_start.to_time + time_add).in_time_zone(user.send_credentials_timezone)
        end
        user.send_credentials_timezone
      rescue 
        user.send_credentials_timezone
      end
    end

    def get_cut_off_time(user)
      (user.if_departed? ? user.get_remove_access_termination_time : user.remove_access_date.to_time) rescue user.remove_access_date
    end

    def get_fields_changed(company, fields_changed, fields)
      fields_changed.map { |field| field['values']  if fields.include?(field['field_id'])}.compact
    end

    def helper_service
      WebhookEventServices::HelperService.new
    end
  end
end
