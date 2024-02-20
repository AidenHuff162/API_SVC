class WorkspaceMemberForm < BaseForm
  presents :workspace_member

  attribute :id, Integer
  attribute :workspace_id, Integer
  attribute :member_id, Integer
end
