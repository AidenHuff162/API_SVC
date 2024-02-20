module PaperworkTemplateSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :document_id, :title, :position

    def title
      object.document.title
    end
  end
end
