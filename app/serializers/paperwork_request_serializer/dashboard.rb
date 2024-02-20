module PaperworkRequestSerializer
  class Dashboard < ActiveModel::Serializer
    attributes :id, :due_date
    has_one :user, serializer: UserSerializer::DashboardPendingDocumentTeamMember
  end
end
