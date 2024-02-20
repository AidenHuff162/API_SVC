class ApplicationMailer < ActionMailer::Base
  include Roadie::Rails::Automatic
  layout 'mailer'
  add_template_helper ApplicationHelper

protected

  def store_email
    if message && message.html_part && message.html_part.body
      message_body = message.html_part.body.decoded
    else
      message_body = message.body.to_s
    end
    if message_body.present?
      company_id = User.where('email = ? OR personal_email = ?',  message.to.to_a.first,  message.to.to_a.first ).first.try(:company_id)
      email = CompanyEmail.create(
        to: message.to.to_a,
        bcc: message.bcc.to_a,
        cc: message.cc.to_a,
        from: message.from.to_a.first,
        subject: CGI.unescapeHTML(message.subject),
        content: message_body,
        sent_at: Time.now,
        company_id: company_id
        )

      message.attachments.each do |attachment|
        filename = attachment.filename
        file = "#{Rails.root}/tmp/#{filename}"
        if file
          begin
            UploadedFile.create(
              entity_type: "CompanyEmail",
              entity_id: email.id,
              file: File.open(file),
              type: "UploadedFile::Attachment"
            )
          rescue
            extension = ""
            strings = filename.split('.')
            extension = strings.last if strings.count > 1
            tempfile = Tempfile.new(['attachment', "." + extension])
            tempfile.binmode
            tempfile.write attachment.body.decoded
            tempfile.rewind
            tempfile.close

            UploadedFile.create(
              entity_type: "CompanyEmail",
              entity_id: email.id,
              file: tempfile,
              type: "UploadedFile::Attachment"
            )
          end
        end
      end
    end
  end

  def from_email(company)
    company = Company.find_by_id(company.id)
    SetUrlOptions.call(company, ActionMailer::Base.default_url_options)

    "#{company.sender_name} <#{company.subdomain}@#{ENV['DEFAULT_HOST']}>"
  end
end
