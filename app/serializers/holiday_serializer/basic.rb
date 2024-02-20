module HolidaySerializer
  class Basic < ActiveModel::Serializer
    type :holiday

    attributes :id, :name, :created_by_name, :begin_date, :end_date, :multiple_dates, :applies_to,
    :team_permission_level, :location_permission_level, :status_permission_level, :created_at,
    :date_range, :updated_at

    def created_by_name
      user = User.find_by(id: object.created_by_id) if object.created_by_id.present?
      user.display_name if user
    end

    def permission_validity
      object.team_permission_level.include?("all") && object.location_permission_level.include?("all") && object.status_permission_level.include?("all")
    end

    def date_range
      date = [object.begin_date, object.end_date]
    end

    def applies_to
      if permission_validity
        return I18n.t('admin.holidays.everyone')
      else
        return I18n.t('admin.holidays.some_employees')
      end
    end
  end
end
