module UserSerializer
  class Inbox < ActiveModel::Serializer
    attributes :id, :picture, :preferred_full_name, :last_name, :preferred_name, :first_name, :start_date,
     :title, :email, :personal_email, :last_day_worked, :date_of_birth, :termination_date, :location_name

    def location_name
    	object&.location&.name
    end
  end
end
