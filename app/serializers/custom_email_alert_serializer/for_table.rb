module CustomEmailAlertSerializer
  class ForTable < ActiveModel::Serializer
    type :custom_email_alert

    attributes :id, :title, :subject, :applied_to_teams, :applied_to_locations, :applied_to_statuses, :updated_at, :edited_by, :is_enabled

    def applied_to_teams
      teams = object.applied_to_teams
      (teams.include? 'all') ? ['All Departments'] : instance_options[:company].teams.where(id: teams).pluck(:name)
    end

    def applied_to_locations
      locations = object.applied_to_locations
      (locations.include? 'all') ? ['All Locations'] : instance_options[:company].locations.where(id: locations).pluck(:name)
    end

    def applied_to_statuses
      statuses = object.applied_to_statuses
      (statuses.include? 'all') ? ['All Statuses'] : statuses.reject(&:empty?)
    end

    def edited_by
      object.edited_by.try(:full_name)
    end
  end
end
