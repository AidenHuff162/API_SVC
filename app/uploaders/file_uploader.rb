# encoding: utf-8

class FileUploader < CarrierWave::Uploader::Base
  include Rails.application.routes.url_helpers
  include CarrierWave::MiniMagick

  before :cache, :save_original_filename
  process convert: 'png', :if => :validate_file_ext

  def filename
    if original_filename.present?
      file_ext = File.extname(original_filename).downcase
      file_ext = '.png' if ['.heic'].include?(file_ext)
      "#{secure_token}#{file_ext}"
    end
  end

  def download_url(filename)
    url(response_content_disposition: %Q{attachment; filename="#{filename.gsub(/[^\-\[\]}0-9A-Za-z@!#$%^&'.,()+=_<>"*?{}~`]/, "")}"})
  end

  private

  def save_original_filename(file)
    if model.respond_to?(:original_filename) && file.respond_to?(:original_filename)
      model.original_filename ||= file.original_filename
    end
  end

  def secure_token
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.hex(8))
  end

  def validate_file_ext(file)
    ['image/heic'].include?(file.content_type)
  end
end
