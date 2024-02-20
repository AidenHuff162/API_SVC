class CompanyValue < ApplicationRecord
  belongs_to :company
  has_one :company_value_image, as: :entity,
          class_name: 'UploadedFile::CompanyValueImage',
          dependent: :destroy
end
