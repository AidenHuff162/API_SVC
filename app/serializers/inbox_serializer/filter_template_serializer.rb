module InboxSerializer
  class FilterTemplateSerializer < ActiveModel::Serializer
    attributes :name, :email_type

    def name
      object.map_email_type
    end
  end
end
