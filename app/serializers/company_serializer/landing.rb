module CompanySerializer
  class Landing < ActiveModel::Serializer
    attributes :id, :name, :logo, :time_zone, :display_name_format

    has_one :landing_page_image
  end
end
