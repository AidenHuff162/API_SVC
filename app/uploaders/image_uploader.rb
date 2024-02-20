# encoding: utf-8

class ImageUploader < FileUploader
  include CarrierWave::MiniMagick

  def extension_white_list
    %w(jpg jpeg gif png)
  end

  version :medium do
    process resize_to_fit: [600, 600]
  end

  version :logo do
    process resize_to_fit: [145, 50]
  end
end
