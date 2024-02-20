module UserSerializer
  class NewArrival < ActiveModel::Serializer
    attributes :id, :picture, :first_name, :last_name, :preferred_name, :preferred_full_name, :start_date, :location_name, :display_name_format

    has_one :profile_image

    def location_name
      object.location.try(:name)
    end

    def display_name_format
    	object.company.display_name_format
    end
    
  end
end
