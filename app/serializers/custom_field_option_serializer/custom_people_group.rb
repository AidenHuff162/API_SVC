module CustomFieldOptionSerializer
  class CustomPeopleGroup < ActiveModel::Serializer
    attributes :id, :option, :people_count

    def people_count
      if object && (defined? object.users)
        object.users.where("start_date <= ? AND state = 'active' and current_stage IN (#{User.current_stages[:first_week]}, #{User.current_stages[:first_month]}, #{User.current_stages[:pre_start]}, #{User.current_stages[:ramping_up]}, #{User.current_stages[:registered]})", Date.today).count
      else
        0
      end
    end
  end
end
