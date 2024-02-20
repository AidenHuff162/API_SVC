FactoryGirl.define do
  factory :uploaded_file do
    file 'adasdasdpoew12ewdasdsadsad.jpg'
    original_filename 'abc.jpg'
    skip_scanning true
  end


  factory :landing_page_image, class: 'UploadedFile::LandingPageImage' do
    file Rack::Test::UploadedFile.new(
      File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png')
    )
  end

  factory :profile_image, class: 'UploadedFile::ProfileImage' do
    trait :for_nick do
      file Rack::Test::UploadedFile.new(
        File.join(Rails.root, 'spec', 'factories', 'uploads', 'users', 'profile_image', 'nick.jpg')
      )
    end

    trait :for_tim do
      file Rack::Test::UploadedFile.new(
        File.join(Rails.root, 'spec', 'factories', 'uploads', 'users', 'profile_image', 'tim.jpg')
      )
    end

    trait :for_peter do
      file Rack::Test::UploadedFile.new(
        File.join(Rails.root, 'spec', 'factories', 'uploads', 'users', 'profile_image', 'peter.jpg')
      )
    end

    trait :for_sarah do
      file Rack::Test::UploadedFile.new(
        File.join(Rails.root, 'spec', 'factories', 'uploads', 'users', 'profile_image', 'sarah.jpg')
      )
    end
  end

  factory :display_logo_image, class: 'UploadedFile::DisplayLogoImage' do
    trait :for_rocketship do
      file Rack::Test::UploadedFile.new(
        File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png')
      )
    end
  end

  factory :milestone_image, class: 'UploadedFile::MilestoneImage' do
    file Rack::Test::UploadedFile.new(
      File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png')
    )
  end

  factory :document_upload_request_file, class: 'UploadedFile::DocumentUploadRequestFile' do
    file Rack::Test::UploadedFile.new(
      File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'doc.pdf')
    )
    skip_scanning true
  end

  factory :pto_upload_file, class: 'UploadedFile::Attachment' do
    file Rack::Test::UploadedFile.new(
      File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'pto_upload.csv')
    )
    skip_scanning true
  end
  
  factory :document_file, class: 'UploadedFile::DocumentFile' do
    file Rack::Test::UploadedFile.new(
      File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'doc.pdf')
    )
    skip_scanning true
  end

  factory :personal_document_file, class: 'UploadedFile::PersonalDocumentFile' do
    file Rack::Test::UploadedFile.new(
      File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'doc.pdf'), 'application/pdf'
    )
    skip_scanning true
  end
end
