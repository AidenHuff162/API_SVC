module CompanySerializer
  class IntegrationPage < ActiveModel::Serializer
    attributes :id, :name, :logo, :authentication_type, :brand_color, :integration_type, :enable_gsuite_integration, :ats_integration_types,
    :paylocity_integration_type, :paylocity_sui_state, :states, :encrypted_slack_params, 
    :display_name_format, :gusto_feature_flag, :webhook_feature_flag, :intercom_feature_flag, :kallidus_v1_feature_flag, :one_login_updates_feature_flag,
    :lever_mapping_feature_flag, :zendesk_admin_feature_flag
    def states
      ISO3166::Country.find_country_by_any_name("United States").states.collect { |key, value| key }
    end

    def encrypted_slack_params
      JsonWebToken.encode({company_id: object.id, user_id: scope[:current_user].id})
    end
  end
end
