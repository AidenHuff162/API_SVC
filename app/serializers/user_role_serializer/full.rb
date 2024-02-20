module UserRoleSerializer
  class Full < Basic
    attributes :id, :position, :description, :is_default, :users_count

    def users_count
      object.users.count
    end

    def permissions
      return object.permissions if @instance_options[:permission] == 'view_and_edit'
    end

    def team_permission_level
      return object.team_permission_level if @instance_options[:permission] == 'view_and_edit'
    end

    def location_permission_level
      return object.location_permission_level if @instance_options[:permission] == 'view_and_edit'
    end

    def status_permission_level
      return object.status_permission_level if @instance_options[:permission] == 'view_and_edit'
    end

    def reporting_level
      return object.reporting_level if @instance_options[:permission] == 'view_and_edit'
    end
  end
end
