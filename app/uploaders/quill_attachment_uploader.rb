# encoding: utf-8

class QuillAttachmentUploader < CarrierWave::Uploader::Base
  include Rails.application.routes.url_helpers
  before :cache, :save_original_filename
  storage :aws
  def initialize(*)
    super
    self.aws_credentials = {
      access_key_id:     ENV['AWS_ACCESS_KEY'],
      secret_access_key: ENV['AWS_SECRET_KEY']
    }
    self.aws_acl       = 'public-read'
    self.aws_bucket    = ENV['PUBLIC_ASSETS_S3_BUCKET']
  end

  def store_dir
    "#{model.company.uuid}/#{model.class.to_s.underscore}"
  end

  def filename
    "#{secure_token}#{File.extname(original_filename).downcase}" if original_filename.present?
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
end
