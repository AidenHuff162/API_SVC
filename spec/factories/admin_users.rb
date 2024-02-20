FactoryGirl.define do
  factory :admin_user do
    email { Faker::Internet.email }
    password { 'secret123$' }
    otp_required_for_login { false }
    expiry_date { Date.today }
  end
end
