FactoryGirl.define do
  factory :deleted_user_email do
    email "MyString"
    personal_email "MyString"
    user nil
  end
end
