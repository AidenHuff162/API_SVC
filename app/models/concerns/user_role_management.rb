module UserRoleManagement
  extend ActiveSupport::Concern

  def assign_default_user_role_ids_to_report(report)
    creator_role_id = report.report_creator_id.present? ? report.company.users.find_by_id(report.report_creator_id).try(:user_role_id) : nil
    user_role_ids = report.company.user_roles.where(name: 'Super Admin').pluck(:id)
    user_role_ids.push(creator_role_id) if creator_role_id.present?
    user_role_ids = report.user_role_ids.push(user_role_ids).flatten.map(&:to_s) unless report.user_role_ids.nil?
    report.update_column(:user_role_ids, user_role_ids.uniq)
  end

  def unassign_user_role_id_to_reports(user_role)
    reports = user_role.company.reports.where("'#{user_role.id}' = ANY (user_role_ids)")
    return if !reports.present?

    reports.try(:find_each) do |report|
      report.update_column(:user_role_ids, report.user_role_ids.delete_if { |x| x == user_role.id.to_s })
    end
  end

  def assign_super_admin_role_id_to_reports(user_role)
    reports = user_role.company.reports
    return if !reports.present? || user_role.role_type != 'super_admin'

    reports.try(:find_each) do |report|
      report.update_column(:user_role_ids, report.user_role_ids.push(user_role.id).uniq)
    end
  end

  def initialize_role_visibility(permissions, key, sub_key, is_super_admin = false)
    permissions[key] = {} if !permissions[key].present?
    permissions[key][sub_key] = is_super_admin.present? ? 'view_and_edit' : 'no_access'

    permissions
  end

  def deinitialize_role_visibility(permissions, key, sub_key)
    permissions[key].delete(sub_key) if permissions[key].present?
    permissions
  end

  def add_custom_table_permissions_to_user_role(company, custom_table_id)
    if custom_table_id.present?
      company.user_roles.try(:each) do |user_role|
        permissions = user_role.permissions

        permissions = initialize_role_visibility(permissions, 'own_role_visibility', custom_table_id.to_s, user_role.super_admin?)
        permissions = initialize_role_visibility(permissions, 'other_role_visibility', custom_table_id.to_s, user_role.super_admin?)

        user_role.update(permissions: permissions)
      end
    end
  end

  def remove_custom_table_permissions_from_user_role(company, custom_table_id)
    if custom_table_id.present?
      company.user_roles.try(:each) do |user_role|
        permissions = user_role.permissions

        permissions = deinitialize_role_visibility(permissions, 'own_role_visibility', custom_table_id.to_s)
        permissions = deinitialize_role_visibility(permissions, 'other_role_visibility', custom_table_id.to_s)

        user_role.update(permissions: permissions)
      end
    end
  end
end
