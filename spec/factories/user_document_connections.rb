FactoryGirl.define do
  factory :user_document_connection do
    user { build(:user) }
  end
end
