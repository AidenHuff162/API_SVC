# encoding: utf-8

class DocumentUploader < FileUploader
  def extension_white_list
    %w(pdf png jpg jpeg heic)
  end
end
