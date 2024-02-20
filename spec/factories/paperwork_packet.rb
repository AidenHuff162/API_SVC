FactoryGirl.define do
  factory :paperwork_packet do
    name Faker::Name.name
    description Faker::Hipster.sentence
    packet_type 0
    company_id 1

    trait :template_skips_validate do
      to_create {|instance| instance.save(validate: false) }
    end

  end
end
