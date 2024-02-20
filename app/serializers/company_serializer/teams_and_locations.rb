module CompanySerializer
  class TeamsAndLocations < ActiveModel::Serializer
    attributes :id, :display_name_format, :xero_enabled, :ohsa_covid_feature_flag
    has_many :teams, serializer: TeamSerializer::Basic
    has_many :locations, serializer: LocationSerializer::Basic

    def teams
      object.teams.where(active: true).order('name')
    end

    def locations
      object.locations.where(active: true).order('name')
    end

    def xero_enabled
      object.is_xero_integrated?
    end
  end
end
