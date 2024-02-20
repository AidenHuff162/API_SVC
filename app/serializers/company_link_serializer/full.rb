module CompanyLinkSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :name, :link, :position, :location_filters , :team_filters, :status_filters
  end
end
