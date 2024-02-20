module CompanySerializer
  class Dashboard < ActiveModel::Serializer
    attributes :id, :name, :plauralize_department, :date_format, :role_types, 
    :is_using_custom_table, :time_zone, :display_name_format, 
    :approval_feature_flag, :enable_custom_table_approval_engine, 
    :intercom_feature_flag, :profile_approval_feature_flag, :zendesk_admin_feature_flag, :has_role_table

    def plauralize_department
      object.department.pluralize
    end

    def is_using_custom_table
      object.is_using_custom_table
    end

    def has_role_table
      object.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information]).present?
    end

  end
end
