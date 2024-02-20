FactoryGirl.define do
  factory :sftp do
    name { Faker::Hipster.word }
    host_url { Faker::Internet.url }
    authentication_key_type { Sftp.authentication_key_types['credentials'] }
    user_name { Faker::Internet.user_name }
    password { Faker::Internet.password }
    port 8080
    folder_path { "#{Rails.root}/spec/fixtures/files/testing_file_#{rand(100)}" }    
    company
    trait :sftp_creator do
    created_by_id
    end
  end
end
