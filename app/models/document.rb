class Document < ApplicationRecord
  has_paper_trail
  acts_as_paranoid
  belongs_to :company
  has_many :paperwork_requests, dependent: :destroy
  has_many :users, through: :paperwork_requests
  has_one :paperwork_template, dependent: :destroy
  has_many :incomplete_paperwork_requests,  -> { where("(paperwork_requests.state = 'assigned' OR paperwork_requests.co_signer_id IS NOT NULL AND paperwork_requests.state NOT IN ('all_signed','draft')) AND (paperwork_requests.due_date is NULL OR paperwork_requests.due_date >= ?)", Company.current.time.to_date) }, class_name: 'PaperworkRequest'
  has_many :incomplete_overdue_paperwork_requests,  -> { where("(paperwork_requests.state = 'assigned' OR paperwork_requests.co_signer_id IS NOT NULL AND paperwork_requests.state NOT IN ('all_signed','draft')) AND paperwork_requests.due_date < ?", Company.current.time.to_date) }, class_name: 'PaperworkRequest'
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE), allow_nil: true
  after_update :remove_packet_connection, if: :precess_type_changed?
  
  with_options as: :entity do |record|
    record.has_one :attached_file, class_name: 'UploadedFile::DocumentFile'
  end

  def duplicate_attachment_file(attachment)
    extenstion = ""
    strings = attachment["original_filename"].split('.')
    extenstion = strings.last if strings.count > 1
    tempfile = Tempfile.new(['attachment', "." + extenstion])
    signature_url = ""
    signature_url = "https://#{ENV['AWS_BUCKET']}.s3.#{ENV['AWS_REGION']}.amazonaws.com" if !Rails.env.development? && !Rails.env.test?
    if !Rails.env.development? && !Rails.env.test?
      open(tempfile.path, 'wb') do |file|
        return unless attachment.file.download_url(attachment.original_filename).include? signature_url
        file.write(HTTP.get(attachment.file.download_url(attachment.original_filename)).body)
      end
    else
      input = File.open("public" + attachment.file.download_url(attachment.original_filename))
      indata = input.read()
      output = File.open(tempfile.path, 'w')
      output.write(indata)
      output.close()
      input.close()
    end
    return UploadedFile.create(entity: self,
                        file: tempfile,
                        type: "UploadedFile::DocumentFile",
                        company_id: self.company_id,
                        original_filename: attachment.original_filename,
                        skip_scanning: true
                       )
  end

  private

  def precess_type_changed?
    self.saved_change_to_meta? && self.paperwork_template && self.saved_changes['meta'][0]["type"] != self.saved_changes['meta'][1]["type"]
  end

  def remove_packet_connection
    self.paperwork_template.paperwork_packet_connections.destroy_all
  end
end
