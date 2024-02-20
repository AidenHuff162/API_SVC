class UserRoleForm < BaseForm
  presents :user_role

  attribute :name, String
  attribute :permissions, JSON
  attribute :company_id, Integer
  attribute :description, String
  attribute :position, Integer
  attribute :reporting_level, Integer
  attribute :team_permission_level, Array[String]
  attribute :location_permission_level, Array[String]
  attribute :status_permission_level, Array[String]
  attribute :role_type, Integer
  attribute :user_role_ids, String

  validates :name, :permissions, :role_type, :company_id, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
end
