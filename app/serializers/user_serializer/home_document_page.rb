module UserSerializer
  class HomeDocumentPage < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name, :preferred_full_name, :company_name, :title, :picture,
               :start_date, :location_id, :team_id, :employee_type, :role, :managed_users_count, :manager_id,
               :user_has_documents, :current_stage, :termination_date, :last_day_worked, :location, :state, :team,
               :date_of_birth, :calendar_prefrences, :header_phone_number, :email, :personal_email,
               :show_performance_tabs, :pto_status, :super_user

    has_one :manager, serializer: UserSerializer::Simple
    has_one :profile_image
    has_one :user_role, serializer: UserRoleSerializer::Basic

    def company_name
      object.company.name
    end

    def employee_type
      object.employee_type
    end

    def location
      object.get_cached_location
    end

    def team
      object.get_cached_team
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def user_has_documents
      object.user_has_documents?
    end

    def date_of_birth
      object.date_of_birth
    end

    def pto_status
      object.pto_status
    end
  end
end
