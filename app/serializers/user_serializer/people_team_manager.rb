module UserSerializer
  class PeopleTeamManager < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name, :picture, :full_name, :preferred_full_name, 
 							 :date_of_birth, :last_day_worked, :termination_date
  end
end
