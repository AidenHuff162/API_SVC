require 'rails_helper'

describe UploadedFileForm::ProfileImageForm, type: :model do
  it { is_expected.not_to validate_presence_of :file}
end

describe UploadedFileForm::MilestoneImageForm, type: :model do
  it { is_expected.to validate_presence_of :file}
end

describe UploadedFileForm::DisplayLogoImageForm, type: :model do
  it { is_expected.not_to validate_presence_of :file}
end

describe UploadedFileForm::LandingPageImageForm, type: :model do
  it { is_expected.not_to validate_presence_of :file}
end

describe UploadedFileForm::GalleryImageForm, type: :model do
  it { is_expected.to validate_presence_of :file}
end

describe UploadedFileForm::SftpPublicKeyForm, type: :model do
  it { is_expected.to validate_presence_of :file}
end
