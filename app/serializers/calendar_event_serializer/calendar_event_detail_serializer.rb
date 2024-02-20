module CalendarEventSerializer
  class CalendarEventDetailSerializer < ActiveModel::Serializer
    attributes :teams, :locations

    def locations
      if object.event_type == 'holiday' && object.eventable.location_permission_level != 'all'
          location_ids = object.eventable.location_permission_level
          object.company.locations.where(id: location_ids).pluck('name')
      end
    end

    def teams
      if object.event_type == 'holiday' && object.eventable.team_permission_level != 'all'
            team_ids = object.eventable.team_permission_level
            object.company.teams.where(id: team_ids).pluck('name')
      end
    end

  end
end
