module PtoRequestSerializer
  class OutOfOffice < ActiveModel::Serializer
    attributes :id, :end_date, :end_time, :partial_day_included, :user_full_name, :user_image, :user_id, :user_initials, :return_date, :user_display_name

    def end_date
      object.end_date.to_datetime.strftime('%-m/%-d/%y')
    end

    def end_time
      object.end_date.to_datetime.utc.strftime("%H:%M %p").downcase
    end

    def user_full_name
      object.user.display_name
    end

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
