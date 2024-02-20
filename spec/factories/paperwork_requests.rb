FactoryGirl.define do
  factory :paperwork_request do
    user_id 1
    document_id 1
    hellosign_signature_id "MyString"
    hellosign_signature_request_id "MyString"
    signed_document { Rack::Test::UploadedFile.new(Rails.root.join('spec/factories/uploads/documents/document.pdf')) }

    trait :request_skips_validate do
      to_create {|instance| instance.save(validate: false) }
    end
  end
end
