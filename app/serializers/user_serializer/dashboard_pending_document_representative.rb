module UserSerializer
  class DashboardPendingDocumentRepresentative < ActiveModel::Serializer
    attributes :first_name, :last_name, :preferred_name, :picture
  end
end
