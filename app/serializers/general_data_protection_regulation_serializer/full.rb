module GeneralDataProtectionRegulationSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :action_type, :action_period, :action_location, :edited_by, :updated_at, :applied_locations

    def edited_by
      object.edited_by&.display_name
    end

    def updated_at
      object.updated_at.in_time_zone(instance_options[:current_company].time_zone).strftime "%H:%M %p %Z"
    end

    def applied_locations
      object.action_location.include?('all') ? ['All'] : instance_options[:current_company].locations.where(id: object.action_location).pluck(:name)
    end
  end
end
