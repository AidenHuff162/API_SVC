module UserSerializer
  class OffboardingBasic < ActiveModel::Serializer
    attributes :id, :email, :personal_email, :title, :first_name, :last_name, :preferred_full_name, :location_name, :start_date, :last_day_worked, :date_of_birth, :termination_date, :preferred_name,
    					 :team, :location, :employee_type
    has_one :manager, serializer: UserSerializer::Minimal
    has_one :buddy, serializer: UserSerializer::Minimal

    def employee_type
    	object.employee_type_field_option&.option if object.employee_type_field_option
    end
  end
end
