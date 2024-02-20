module ProfilePermissions
  extend ActiveSupport::Concern

  def get_profile_permissions(user)
    {
      personal_info:  UserRolesCollection.new(profile_permission_params(user, 'personal_info')).results,
      private_info:  UserRolesCollection.new(profile_permission_params(user, 'private_info')).results,
      additional_info:  UserRolesCollection.new(profile_permission_params(user, 'additional_info')).results
    }
  end

  private
  def profile_permission_params(user, section)
    params.merge(company_id: user.company_id,
                  user_team_id: user.team_id,
                  user_location_id: user.location_id,
                  user_employee_type: user.employee_type,
                  section: section,
                  profile_page: true)
  end

end
