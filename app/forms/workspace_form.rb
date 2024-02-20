class WorkspaceForm < BaseForm
  presents :workspace

  PLURAL_RELATIONS = %i(workspace_members)

  attribute :name, String
  attribute :company_id, Integer
  attribute :time_zone, String
  attribute :associated_email, String
  attribute :workspace_image_id, Integer
  attribute :workspace_members, Array[WorkspaceMemberForm]

  validates :name, :company_id, presence: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
end
