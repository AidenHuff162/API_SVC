class UserRole < ApplicationRecord
  include UserRoleManagement

  has_paper_trail
  belongs_to :company
  has_many :users

  before_destroy :update_user_roles
  before_destroy { |action| action.unassign_user_role_id_to_reports(self) }

  after_create { |action| action.assign_super_admin_role_id_to_reports(self) }

  enum role_type: { employee: 0, manager: 1, admin: 2, super_admin: 3 }
  enum reporting_level: { direct: 0, direct_and_indirect: 1 }

  validates_presence_of :name, :permissions, :role_type
  validate :permissions_validity, :lde_validity
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE), allow_nil: true


  def is_time_off_visibility_valid?
    self.permissions["platform_visibility"].key?("time_off") && self.permissions["platform_visibility"]["time_off"].present?
  end

  def is_time_off_platform_visibility_nil?
    self.permissions.key?('platform_visibility') && self.permissions.key?('platform_visibility').present? && !self.permissions["platform_visibility"].key?("time_off")
  end

  def is_time_off_admin_visibility_nil?
    self.permissions.key?("admin_visibility") && self.permissions["admin_visibility"].present? && !self.permissions["admin_visibility"].key?("time_off")
  end

  def role_not_changed? previous_role
    return previous_role.present? && (previous_role.permissions == self.permissions && previous_role.reporting_level == self.reporting_level && previous_role.team_permission_level == self.team_permission_level && previous_role.location_permission_level == self.location_permission_level && previous_role.status_permission_level == self.status_permission_level) 
  end

  private

  def update_user_roles
    employee_role = self.company.user_roles.where(role_type: UserRole.role_types[:employee], is_default: true).first rescue nil
    self.users.try(:find_each) do |user|
      user.update_columns(role: 0, user_role_id: employee_role.id)
      user.flush_cached_role_name
    end if employee_role.present?
  end

  def permissions_validity
    errors.add(:Permission, I18n.t('models.user_role.invalid_permissions')) if !permissions_are_valid?
  end

  def permissions_are_valid?
    if self.role_type.present?
      if self.role_type == 'employee' || self.role_type == 'manager'
        return is_platform_visibility_valid? && is_employee_record_visibility_valid?

      elsif self.role_type == 'admin' || self.role_type == 'super_admin'
        return is_platform_visibility_valid? && is_employee_record_visibility_valid? && is_admin_visibility_valid?
      end
    end

    false
  end

  def is_platform_visibility_valid?
    self.permissions.present? && self.permissions.key?("platform_visibility") && self.permissions["platform_visibility"].present? && self.permissions["platform_visibility"].key?("profile_info") && self.permissions["platform_visibility"]["profile_info"].present? && self.permissions["platform_visibility"].key?("task") && self.permissions["platform_visibility"]["task"].present? && self.permissions["platform_visibility"].key?("document") && self.permissions["platform_visibility"]["document"].present? && is_calendar_visibility_valid?
  end

  def is_calendar_visibility_valid?
    self.permissions["platform_visibility"].key?("calendar") && self.permissions["platform_visibility"]["calendar"].present?
  end

  def is_employee_record_visibility_valid?
    self.permissions.present? && self.permissions.key?("employee_record_visibility") && self.permissions["employee_record_visibility"].present? && self.permissions["employee_record_visibility"].key?("private_info") && self.permissions["employee_record_visibility"]["private_info"].present? && self.permissions["employee_record_visibility"].key?("personal_info") && self.permissions["employee_record_visibility"]["personal_info"].present? && self.permissions["employee_record_visibility"].key?("additional_info") && self.permissions["employee_record_visibility"]["additional_info"].present?
  end

  def is_admin_visibility_valid?
    self.permissions.present? && self.permissions.key?("admin_visibility") && self.permissions["admin_visibility"].present? && self.permissions["admin_visibility"].key?("dashboard") && self.permissions["admin_visibility"]["dashboard"].present? && self.permissions["admin_visibility"].key?("reports") && self.permissions["admin_visibility"]["reports"].present? && self.permissions["admin_visibility"].key?("records") && self.permissions["admin_visibility"]["records"].present? && self.permissions["admin_visibility"].key?("documents") && self.permissions["admin_visibility"]["documents"].present? && self.permissions["admin_visibility"].key?("tasks") && self.permissions["admin_visibility"]["tasks"].present? && self.permissions["admin_visibility"].key?("general") && self.permissions["admin_visibility"]["general"].present? && self.permissions["admin_visibility"].key?("groups") && self.permissions["admin_visibility"]["groups"].present? && self.permissions["admin_visibility"].key?("emails") && self.permissions["admin_visibility"]["emails"].present? && self.permissions["admin_visibility"].key?("integrations") && self.permissions["admin_visibility"]["integrations"].present?
  end

  def lde_validity
    if (self.status_permission_level[0] == "" && self.status_permission_level.length == 1) || 
    (self.team_permission_level[0] == "" && self.team_permission_level.length == 1) || 
    (self.location_permission_level[0] == "" && self.location_permission_level.length == 1)
      errors.add(:Permission, I18n.t('Permission levels cannot be empty.'))
    end
  end

end
