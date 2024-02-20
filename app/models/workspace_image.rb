class WorkspaceImage < ApplicationRecord
  mount_uploader :image, FileUploader

  def self.create_workspace_image(url = '', filename = '')
    return if url.blank? || filename.blank?

    image = WorkspaceImage.new
    image.image = File.open(url + filename)
    image.save!
  end
end
