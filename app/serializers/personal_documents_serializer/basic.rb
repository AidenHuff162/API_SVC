module PersonalDocumentsSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :title, :description, :document_url

    def document_url
      return unless object.attached_file
      
      filename = object.title + File.extname(object.attached_file.original_filename)
      object.attached_file.file.download_url(filename) 
    end
  end
end
