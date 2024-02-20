FactoryGirl.define do

  factory :inventory_field_mapping do
    inventory_field_key { Faker::Name.name }
    inventory_field_name { Faker::Name.name }
  end
end