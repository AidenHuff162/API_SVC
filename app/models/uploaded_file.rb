class UploadedFile < ApplicationRecord
  belongs_to :entity, polymorphic: true
  scope :expired, -> { where(entity_id: nil).where('updated_at < ? AND type != ?', 1.day.ago, 'UploadedFile::QuillAttachment') }

  after_save :trigger_algolia_sync
  attr_accessor :skip_scanning

  def trigger_algolia_sync
    User.trigger_algolia_worker(self.entity, false) if (self.entity_type == 'User' && self.type == 'UploadedFile::ProfileImage')
  end

  def clear_file
    self.remove_file!
    save
  end

  def scan_file_for_virus
    if !(file.model && (file.model.entity_type == 'Task' || file.model.entity_type == 'EmailTemplate'))
      scan_result = nil
      begin
        scan_result = self.skip_scanning || Clamby.safe?(file.path)
      rescue Exception => e
      end
      logger.info "=====2Scanning File======"
      logger.info scan_result
      logger.info "=====Scanning File======"

      if !scan_result.present? && !scan_result.nil?
        begin
          File.delete(file.path)
        rescue Exception => e
        end
        raise 'Malicious File'
      end
    end
  end

  def validate_file_size
    if !(file.model && (file.model.entity_type == 'Task' || file.model.entity_type == 'EmailTemplate'))
      raise 'Invalid File Size' unless get_file.size <= 20.megabytes
    end
  end

  class DocumentFile < self
    mount_uploader :file, DocumentUploader
    before_save :scan_file_for_virus

    def url_for_hellosign
      if !Rails.env.development? && !Rails.env.test?
        return self.file.url
      else
        return self.file.current_path
      end
    end
  end

  class PersonalDocumentFile < self
    mount_uploader :file, DocumentUploader
    before_save :validate_file
    before_save :validate_file_size
    before_save :scan_file_for_virus

    def validate_file
      raise 'Invalid File Type' unless ['application/pdf', 'image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp', 'image/heic', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'].include?(get_file.content_type)
    end
  end

  class DocumentUploadRequestFile < self
    mount_uploader :file, DocumentUploader
    before_save :validate_file
    before_save :validate_file_size
    before_save :scan_file_for_virus

    def validate_file
      raise 'Invalid File Type' unless Rails.env.test? || ['application/pdf', 'image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp', 'image/heic', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'].include?(get_file.content_type)
    end
  end

  class ProfileImage < self
    acts_as_paranoid

    mount_uploader :file, ProfileImageUploader
    before_save :validate_file
    after_update :update_org_chart, if: Proc.new{|image| image.saved_change_to_entity_id?}

    def validate_file
      raise 'Invalid Image Size' if get_file.size > 20.megabytes
    end

    private

    def update_org_chart
      self.entity.run_update_organization_chart_job if self.entity.present?
    end
  end

  class WorkspaceImage < self
    mount_uploader :file, ImageUploader
  end

  class MilestoneImage < self
    mount_uploader :file, ImageUploader

    def image_size
      if Rails.env == "development" || Rails.env == "test"
        url = self.file.path
      else
         url = self.file.file.file rescue nil # GET AWS Object
         url = url.presigned_url(:get, expires_in: 3600) if url
      end
      image_size = url.present? ? MiniMagick::Image.open(url) : { width: 0 }
      image_info = {}
      image_info[:width] = image_size[:width]
      image_info
    end

  end

  class CompanyValueImage < self
    mount_uploader :file, ImageUploader
  end

  class DisplayLogoImage < self
    mount_uploader :file, DisplayLogoImageUploader
  end

  class DialogDisplayLogoImage < self
    mount_uploader :file, DisplayLogoImageUploader
  end

  class LandingPageImage < self
    mount_uploader :file, ImageUploader
  end

  class GalleryImage < self
    mount_uploader :file, ImageUploader
    before_save :validate_file

    def validate_file
      raise 'Invalid File Type' unless ['image/gif', 'image/png', 'image/jpeg', 'image/jpg', 'image/webp'].include?(get_file.content_type)
    end
  end

  class Attachment < self
    mount_uploader :file, FileUploader
    before_save :validate_file_type
    before_save :validate_file_size
    before_save :scan_file_for_virus

    def validate_file_type
      if !(file.model && (file.model.entity_type == 'Task' || file.model.entity_type == 'EmailTemplate' || file.model.entity_type == 'PtoRequest'))
        raise 'Invalid File Type' unless ['application/vnd.ms-powerpoint', 'application/vnd.ms-excel', 'application/pdf', 'text/plain', 'image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp',
                                          'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                                          'application/msword', 'application/vnd.ms-office', 'application/zip', 'text/comma-separated-values', 'text/csv', 
                                          'application/vnd.openxmlformats-officedocument.presentationml.presentation'].include? get_file.content_type
      end
    end
  end

  class QuillAttachment < self
    mount_uploader :file, QuillAttachmentUploader
    belongs_to :company
    before_save :validate_file_type
    before_save :validate_file_size
    before_save :scan_file_for_virus

    def validate_file_type
      if !(file.model && file.model.entity_type == 'EmailTemplate')
        raise 'Invalid File Type' unless ['application/vnd.ms-powerpoint', 'application/vnd.ms-excel', 'application/pdf', 'text/plain', 'image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp',
                                          'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                                          'application/msword', 'application/vnd.ms-office', 'application/zip', 'text/comma-separated-values', 'text/csv'].include? get_file.content_type
      end
    end
  end

  def get_file
    self.id.present? ? UploadedFile.find(self.id).file : self.file
  end

  class SftpPublicKey < self
    mount_uploader :file, SftpPublicKeyUploader
    before_save :validate_file_type
    before_save :scan_file_for_virus
    before_save :validate_file_size
    
    def validate_file_type
      raise 'Invalid File Type' unless ['txt', 'pem', 'ppk'].include?(get_file.file.extension)
    end
 end
end
