module PtoRequestSerializer
  class OutOfOfficeUpdates < ActiveModel::Serializer
    attributes :id, :user_image, :user_id, :user_initials, :return_date, :user_display_name, :partial_day_included

    def user_image
      object.user.picture
    end

    def user_initials
      "#{object.user.preferred_full_name[0,1] } #{object.user.last_name[0,1]}"
    end

    def return_date
      object.get_return_day(false)
    end

    def user_display_name
      object.user.company.global_display_name(object.user, object.user.company.display_name_format)
    end
  end
end
