class CompanyEmail < ApplicationRecord
  has_many :attachments, as: :entity, dependent: :destroy,
                        class_name: 'UploadedFile::Attachment'
  belongs_to :company

  def self.ransackable_scopes(_opts)
    [:sent_to, :cc_email, :bcc_email]
  end

  def self.sent_to(query)
    where("array_to_string(company_emails.to, ', ') ILIKE ?", "%#{query}%")
  end

  def self.cc_email(query)
    where("array_to_string(company_emails.cc, ', ') ILIKE ?", "%#{query}%")
  end

  def self.bcc_email(query)
    where("array_to_string(company_emails.bcc, ', ') ILIKE ?", "%#{query}%")
  end
end
