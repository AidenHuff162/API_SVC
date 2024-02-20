module IntegrationSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :api_name, :api_key, :secret_token, :channel, :is_enabled, :webhook_url, :subdomain,
               :signature_token, :enable_create_profile, :client_id, :api_company_id, :client_secret,
               :company_code, :public_key_file_url, :jira_issue_type, :jira_issue_statuses, :jira_complete_status,
               :identity_provider_sso_url, :saml_certificate, :saml_metadata_endpoint, :subscription_id,
               :access_token, :gsuite_account_url, :gsuite_admin_email, :gsuite_auth_credentials_present,
               :encrypted_secret_token, :encrypted_api_key, :encrypted_signature_token, :encrypted_client_secret,
               :encrypted_access_token, :can_import_data, :region, :enable_update_profile, :asana_organization_id,
               :asana_default_team, :asana_personal_token, :encrypted_iusername,:encrypted_ipassword, :iusername,
               :ipassword, :workday_human_resource_wsdl, :meta, :link_gsuite_personal_email, :can_export_updation,
               :hiring_context, :encrypted_request_token, :enable_onboarding_templates, :employee_group_name, :payroll_calendar_id,
               :earnings_rate_id, :get_last_sync_date, :get_last_sync_time, :can_invite_profile, :can_delete_profile, 
               :is_deputy_authenticated, :is_adfs_authenticated, :enable_company_code, :enable_international_templates,
               :get_last_sync_status, :enable_tax_type, :sync_preferred_name, :hiring_context

    def public_key_file_url
      filename = "public_key.pdf"
      object.public_key_file.download_url(filename)
    end

    def encrypted_secret_token
      object.secret_token.gsub(/.(?=.{4,}$)/,'*') if object.secret_token.present?
    end

    def encrypted_api_key
      object.api_key.gsub(/.(?=.{4,}$)/,'*') if object.api_key.present?
    end

    def encrypted_signature_token
      object.signature_token.gsub(/.(?=.{4,}$)/,'*') if object.signature_token.present?
    end

    def encrypted_client_secret
      object.client_secret.gsub(/.(?=.{4,}$)/,'*') if object.client_secret.present?
    end

    def encrypted_access_token
      object.access_token.gsub(/.(?=.{4,}$)/,'*') if object.access_token.present?
    end

    def encrypted_iusername
      object.iusername.gsub(/.(?=.{4,}$)/,'*') if object.iusername.present?
    end

    def encrypted_ipassword
      object.ipassword.gsub(/.(?=.{4,}$)/,'*') if object.ipassword.present?
    end

    def get_last_sync_date
      object.try(:last_sync).to_date.strftime(object.try(:company).get_date_format) if object.last_sync
    end
    
    def get_last_sync_time
      object.try(:last_sync).in_time_zone(object.try(:company).time_zone).strftime("%I:%M%p") if object.last_sync
    end
    
    def is_deputy_authenticated
      object.refresh_token && object.access_token && object.subdomain && object.client_id && object.client_secret
    end
    
    def is_adfs_authenticated
      object.access_token && object.company_code && object.gsuite_account_url && object.client_id && object.client_secret
    end

    def get_last_sync_status
      object.last_sync_status
    end
  end
end
