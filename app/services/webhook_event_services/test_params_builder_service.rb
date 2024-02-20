module WebhookEventServices
  class TestParamsBuilderService

    def prepare_test_event_params(company, event_data, webhook)
      params = { webhook_event: prepare_customer_params(company) }

      params.merge!(test_request: true) unless webhook.zapier? 

      case webhook.event
      when 'new_pending_hire'
        params[:webhook_event].merge!(prepare_pending_hire_params(company, event_data, webhook.zapier?))
      when 'stage_completed', 'stage_started'
        event_data.merge!(stage: "invited")
        params[:webhook_event].merge!(prepare_stage_changed_params(company, event_data, webhook, webhook.zapier?))
      when 'key_date_reached'
        params[:webhook_event].merge!(prepare_key_date_reached_params(company, event_data, webhook))
      when 'profile_changed', 'job_details_changed'
        params[:webhook_event].merge!(prepare_profile_changed_params(webhook, company, webhook.zapier?))
      when 'onboarding'
        params[:webhook_event].merge!(user_onboarding_params(company, event_data, webhook,webhook.zapier?))
      when 'offboarding'
        params[:webhook_event].merge!(user_offboarding_params(company, event_data, webhook,webhook.zapier?))
      end

      return params
    end
    
    def prepare_customer_params(company)
      {
        customer: {
          domain: company.domain,
          companyID: company.uuid 
        }
      }
    end

    def prepare_pending_hire_params(company, event_data, is_zapier_webhook)
      action = is_zapier_webhook ? 'created' : event_data['action']
      params = { pending_hire: { action: action, source: 'https://www.kallidus.com' } }
      params[:pending_hire].merge!({
        personalEmail: "sarah@gmail.com",
        firstName: "Sarah Salem",
        preferredName: "Reichert salem",
        lastName: "Salem",
        startDate: (DateTime.now.to_date).strftime('%Y-%m-%d'),
        jobTitle: "Software Engineer",
        department: "Development",
        location: "San Francisco",
        status: "inactive",
        employmentStatus: "part time",
        pendingHireId: "7dfd4316f-1d4d-4da7-8d6e-a1bfb642aeae",
      })

      params
    end

    def user_onboarding_params(company, event_data, webhook, is_zapier_webhook)
     params = {
      eventType: event_data[:type],
      eventTime: Time.now,
      eventActivity: {
        activityState: 'started',
        activityInitiatedByGuid: '6'
      }
     }
      params.merge!({
        email: "sarah@gmail.com",
        personalEmail: "sarah1122@gmail.com",
        firstName: "Sarah Salem",
        preferredName: "Rocker salem",
        lastName: "Saleem",
        userGuid: "gu-7dfd4316f-1d4d-4da7-8d6e-a1bfb642aeae",
        userId: "7",
        status: "active",
        current_stage: "Invited",
        startDate: (DateTime.now.to_date).strftime('%Y-%m-%d'),
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
        accountProviderSchedule: "immediately",
        accountProvisionTime: (DateTime.now.to_date).strftime('%Y-%m-%d')
        }) if auth_type || provision_type
  
      if is_zapier_webhook
        activityState = webhook.configurable['stages'].include?("all") ? 'started' : webhook.configurable['stages'].reject(&:blank?)[0]
        params[:eventActivity][:activityState]= activityState
      end
      params
    end

    def user_offboarding_params(company, event_data, webhook, is_zapier_webhook)
     params = {
      eventType: event_data[:type],
      eventTime: Time.now,
      eventActivity: {
        activityState: event_data[:stage],
        activityInitiatedByGuid: event_data[:triggered_by]
      }
     }
     params.merge!({
        email: "sarah@gmail.com",
        personalEmail: "sarah1122@gmail.com",
        firstName: "Sarah Salem", 
        preferredName: "Rocker salem",
        lastName: "Saleem",
        userGuid: "gu-7dfd4316f-1d4d-4da7-8d6e-a1bfb642aeae",
        userId: "9",
        status: "Inactive",
        current_stage: "Invited",
        terminationDate: (DateTime.now.to_date).strftime('%Y-%m-%d'),
        lastDayWorked: (DateTime.now.to_date).strftime('%Y-%m-%d'),
        terminationType: "voluntary",
        eligibleForRehire: "Yes",
        accessCutOff:{
          accessCutOffSchedule: "default",
          accessCutOffTime: (DateTime.now.to_date).strftime('%Y-%m-%d')
        }
      })
      if is_zapier_webhook
        activityState = webhook.configurable['stages'].include?("all") ? 'started' : webhook.configurable['stages'].reject(&:blank?)[0]
        params[:eventActivity][:activityState]= activityState
      end
      params
    end

    def prepare_stage_changed_params(company, event_data, webhook, is_zapier_webhook)
      params = { user: user_params() }

      if is_zapier_webhook
        stageType = webhook.configurable['stages'].include?("all") ? 'invited' : webhook.configurable['stages'].reject(&:blank?)[0]
        key = webhook.event == 'stage_completed' ? 'StageCompleted' : 'StageStarted' 
        params[:user].merge!("#{key}": stageType)
      else
        params[:user].merge!({"#{event_data['type'].camelcase}": event_data['stage']})
      end
 
      params
    end

    def prepare_key_date_reached_params(company, event_data, webhook)
      params = { user: user_params() }
      dateType = webhook.configurable['date_types'].include?("all") ? ['birthday'] : webhook.configurable['date_types'].reject(&:blank?)
      params[:user].merge!({keydatesReached: { date: company.time.to_date, dateType: dateType }})
      
      params
    end

    def prepare_profile_changed_params(webhook, company, is_zapier_webhook)
      configurables = webhook.configurable['fields'].reject(&:blank?).sample
      fields_changed = company.prefrences['default_fields'].map { |field| field['name'] if configurables.eql?(field['api_field_id'])}.compact + company.custom_fields.where(api_field_id: configurables).pluck(:name)
      params =  { 
        user: {
          email: "sarah@gmail.com",
          userId: "7dfd4316f-1d4d-4da7-8d6e-a1bfb642aeae",
          fields_changed: {
            date: (DateTime.now.to_date).strftime('%Y-%m-%d'),
          }
        }
      }

      if is_zapier_webhook
        params[:user][:fields_changed].merge!(fields: fields_changed.first + " changed")
      else
        params[:user][:fields_changed].merge!(fields: {fieldName: fields_changed.first, oldValue: 'Dummy old value', newValue: 'Dummy new value'})
      end

      params
    end

    private

    def user_params
      {
        email: "sarah@gmail.com",
        firstName: "Sarah Salem",
        preferredName: "Reichert salem",
        lastName: "Salem",
        startDate: (DateTime.now.to_date).strftime('%Y-%m-%d'),
        jobTitle: "Software Engineer",
        department: "Development",
        location: "San Francisco",
        status: "active",
        employmentStatus: "part time",
        userId: "7dfd4316f-1d4d-4da7-8d6e-a1bfb642aeae"
      }
    end
  end
end
