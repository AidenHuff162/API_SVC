FactoryGirl.define do
  factory :paperwork_template do
    document_id 1
    hellosign_template_id "MyString"
    company_id 1
    state "saved"

    trait :template_skips_validate do
      to_create {|instance| instance.save(validate: false) }
    end
  end
end
