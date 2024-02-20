module Attachments
 class UploadAttachments

   def self.perform(attachment, type) 
     UploadedFile.create({
        entity_type: type,
        file: attachment.file,
        type: 'UploadedFile::Attachment',
        company_id: attachment.company_id,
        original_filename: attachment.original_filename,
        skip_scanning: true
      })
    end
  end
end  