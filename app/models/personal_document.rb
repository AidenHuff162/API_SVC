class PersonalDocument < ApplicationRecord
  include UserStatisticManagement

  acts_as_paranoid
  belongs_to :user
  belongs_to :created_by, class_name: 'User', foreign_key: :created_by_id
  validates_format_of :title, with: Regexp.new(AvoidHtml::HTML_REGEXP), allow_nil: true
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE), allow_nil: true
 
  with_options as: :entity do |record|
    record.has_one :attached_file, class_name: 'UploadedFile::PersonalDocumentFile'
  end
end