module CompanySerializer
  class CompanyGroup < ActiveModel::Serializer
    attributes :id, :singular_department, :plauralize_department, :integration_type, :is_using_custom_table, :display_name_format, :company_plan, :smart_assignment_2_feature_flag, :prefrences, :ui_switcher_feature_flag

    def plauralize_department
      object.department.pluralize
    end
  end
end
