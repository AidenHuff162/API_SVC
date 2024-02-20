FactoryGirl.define do
  factory :document_upload_request do
    global true
    meta  { { "team_id"=>["all"], "location_id"=>["all"], "employee_type"=>["all"] } }
    factory :request_with_connection_relation, parent: :document_upload_request  do
      user { build(:user) }
      special_user { build(:user) }
      after(:create) do |document_upload_request|
        create(:document_connection_relation, document_upload_request: document_upload_request)
      end
    end
  end
end
