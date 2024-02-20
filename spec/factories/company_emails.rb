FactoryGirl.define do
  factory :company_email do
    subject { Faker::Name.first_name }
    content { Faker::Company.bs }
  end
end