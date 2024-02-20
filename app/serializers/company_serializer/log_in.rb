module CompanySerializer
  class LogIn < ActiveModel::Serializer
    attributes :id, :name, :logo, :authentication_type, :show_saml_login_button, :show_adfs_link, :adfs_sso_link, :brand_color, :login_type, 
    :show_azure_link, :custom_tables_count, :is_using_custom_table, :ui_switcher_feature_flag, :ids_authentication_feature_flag

    def adfs_sso_link
      url = ''
      if show_adfs_link
        url = object.integration_instances.find_by(api_identifier: 'active_directory_federation_services', state: :active).identity_provider_sso_url
      end
      url
    end

    def show_adfs_link
      integration = object.integration_instances.find_by(api_identifier: 'active_directory_federation_services', state: :active)
      object.authentication_type == 'active_directory_federation_services' and integration.present? and integration.saml_certificate.present? and integration.identity_provider_sso_url.present?
    end

    def show_azure_link
      integration = object.integration_instances.find_by(api_identifier: 'adfs_productivity', state: :active)
      return true if integration.present?
      return false
    end

    def custom_tables_count
      object.get_cached_custom_tables_count
    end
  end
end
