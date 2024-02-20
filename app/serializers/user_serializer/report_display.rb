module UserSerializer
  class ReportDisplay < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name
  end
end
