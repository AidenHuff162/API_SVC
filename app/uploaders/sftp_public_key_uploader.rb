class SftpPublicKeyUploader < FileUploader
  def extension_white_list
    %w(txt pem ppk)
  end
end
