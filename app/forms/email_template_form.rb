class EmailTemplateForm < BaseForm
  presents :email_template

  attribute :subject, String
  attribute :email_to, String
  attribute :cc, String
  attribute :bcc, String
  attribute :description, String
  attribute :name, String
  attribute :invite_in, Integer
  attribute :invite_date, DateTime

  validates :subject, :description, :name, presence: true
 end
