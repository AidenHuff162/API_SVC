module PtoPolicySerializer
  class Index < ActiveModel::Serializer
    type :pto_policy

    attributes :id, :name, :policy_type, :accrual_type, :for_all_employees, :icon, :filter_policy_by, :is_enabled,
               :user_count, :request_count, :assign_manually, :updated_at_date, :updated_by

    def policy_type
      object.policy_type.titleize
    end

    def accrual_type
      if object.unlimited_policy
        if object.unlimited_type_title.present?
          object.unlimited_type_title
        else
          I18n.t("admin.settings.pto_policies.unlimited")
        end
      else
        I18n.t("admin.settings.pto_policies.limited")
      end
    end

    def for_all_employees
      if object.for_all_employees
        I18n.t("admin.settings.pto_policies.everyone")
      elsif !object.for_all_employees && !object.assign_manually
        I18n.t("admin.settings.pto_policies.some_employees")
      elsif !object.for_all_employees && object.assign_manually
        I18n.t("admin.settings.pto_policies.manual_assign")
      end
    end

    def user_count
      object.users.size
    end

    def request_count
      object.pto_requests.size
    end

    def updated_at_date
      object.try(:updated_at).to_date.strftime(object.try(:company).get_date_format) if object.updated_at
    end

    def updated_by
      if object.editor.present?
        object.editor.display_name
      else
        "Admin"
      end
    end

  end
end
