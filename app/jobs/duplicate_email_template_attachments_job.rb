class DuplicateEmailTemplateAttachmentsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :duplicate_attachments, :retry => false, :backtrace => true

  def perform(user_email_id, template_attachments)
    if template_attachments.present?
      template_attachments.try(:each) do |attachment|
        begin
          create_duplicate_attachment(attachment, user_email_id, "UserEmail")
        rescue Exception => e
          puts "-------------- Duplicate Attachment error -------------\n"*8
          puts "UserEmailId = #{user_email_id}" 
          puts attachment.inspect
          puts "\nError = #{e.inspect}"
          puts "---------------------------------------------------------"
        end
      end
    end
  end

  def duplicate_attachments_without_entity(template_attachments)
    duplicated_attachments = []
    template_attachments.try(:each) do |attachment|
      duplicated_attachments << create_duplicate_attachment(attachment)
    end
    duplicated_attachments
  end

  private

  def create_duplicate_attachment(attachment, user_email_id=nil, entity_type=nil)
    extenstion = ""
    strings = attachment["original_filename"].split('.')
    extenstion = strings.last if strings.count > 1

    tempfile = Tempfile.new(['attachment', "." + extenstion])
    signature_url = ""
    signature_url = "https://#{ENV['AWS_BUCKET']}.s3.#{ENV['AWS_REGION']}.amazonaws.com" if !Rails.env.development? && !Rails.env.test?
    if !Rails.env.development? && !Rails.env.test?
      open(tempfile.path, 'wb') do |file|
        return unless attachment["download_url"].include? signature_url
        file.write(HTTP.get(attachment["download_url"]).body)
      end

    else
      input = File.open("public" + attachment["download_url"])
      indata = input.read()
      output = File.open(tempfile.path, 'w')
      output.write(indata)
      output.close()
      input.close()
    end

    return UploadedFile.create(entity_type: entity_type,
                        file: tempfile,
                        type: "UploadedFile::Attachment",
                        company_id: attachment["company_id"],
                        original_filename: attachment["original_filename"],
                        entity_id: user_email_id,
                        skip_scanning: true
                       )
  end

end
