module UserRoleSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :permissions, :reporting_level, :team_permission_level, :role_type, :location_permission_level,
               :status_permission_level
  end
end
