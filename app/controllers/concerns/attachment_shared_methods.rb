module AttachmentSharedMethods
  extend ActiveSupport::Concern
  
  def attachment_ids
    @attachment_ids ||= (params[:attachments] || []).map do |attachment|
      attachment[:id]
    end
  end

  def authorize_attachments
    UploadedFile::Attachment.where(id: attachment_ids).find_each do |attachment|
      authorize! :manage, attachment
    end
  end

  def upload_attachment attachment
    UploadedFile.create({
      entity_type: 'Task',
      file: attachment.file,
      type: 'UploadedFile::Attachment',
      company_id: attachment.company_id,
      original_filename: attachment.original_filename
    }) rescue nil
  end

end