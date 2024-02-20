module CompanyLinkSerializer
  class UpdatesPage < ActiveModel::Serializer
    attributes :name, :link, :position
  end
end
