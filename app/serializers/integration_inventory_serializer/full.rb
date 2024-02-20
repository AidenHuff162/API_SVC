module IntegrationInventorySerializer
  class Full < ActiveModel::Serializer
    attributes :id, :display_name, :dialog_logo_url, :status, :category, :knowledge_base_url, :data_direction,
               :enable_filters, :enable_test_sync, :state, :api_identifier, :integration_configurations, :existing_filters,
               :enable_multiple_instance, :integration_instances, :enable_authorization, :enable_connect, :field_mapping_option,
               :default_field_prefrences, :custom_fields, :inventory_field_mappings, :mapping_description, :field_mapping_direction

    def integration_configurations
      ActiveModelSerializers::SerializableResource.new(get_visible_integration_configurations, each_serializer: IntegrationConfigurationSerializer::Full)
    end

    def integration_instances
      ActiveModelSerializers::SerializableResource.new(@instance_options[:instances], each_serializer: IntegrationInstanceSerializer::Full, company: @instance_options[:current_company])
    end

    def existing_filters
      IntegrationInstance.fetch_exisiting_filters(@instance_options[:instances].pluck(:id), @instance_options[:current_company].id, object.category).pluck(:filters)
    end

    def dialog_logo_url
      object.dialog_logo_url(@instance_options[:current_company].id)
    end

    def inventory_field_mappings
      object.inventory_field_mappings
    end

    def default_field_prefrences
      company = @instance_options[:current_company]
      company.default_field_prefrences_for_mapping(object.field_mapping_option)
    end

    def custom_fields
      company = @instance_options[:current_company]
      custom_fields = company.get_custom_fields_for_mapping(object.field_mapping_option)
      if custom_fields.present?
        ActiveModelSerializers::SerializableResource.new(custom_fields, each_serializer: CustomFieldSerializer::Basic)
      else
        nil
      end
    end

    def get_visible_integration_configurations
      company = @instance_options[:current_company]
      visible_configurations = object.visible_integration_configurations
      if object.api_identifier === 'one_login'
        invisible_configurations = company.one_login_updates_feature_flag ? object.invisible_integration_configurations : []
        return visible_configurations + invisible_configurations
      end

      visible_configurations
    end
  end
end
