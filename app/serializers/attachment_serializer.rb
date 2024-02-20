class AttachmentSerializer < ActiveModel::Serializer
  attributes :id, :original_filename, :entity_id, :entity_type, :position, :download_url, :file_size, :company_id
  has_one :file

  def download_url
    object.file.download_url(object.original_filename)
  end

  def file_size
    object.file.size / 1000 rescue 0 if object.file
  end
end
