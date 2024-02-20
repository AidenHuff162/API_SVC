FactoryGirl.define do
  factory :document do
    company_id 1
    title { Faker::Company.name }

    factory :document_with_paperwork_template do
      after(:create) do |document|
        create(:paperwork_template, :template_skips_validate, document_id: document.id, company_id: document.company_id)
      end
    end

    factory :document_with_paperwork_template_with_representative_id do
      after(:create) do |document|
        representative = create(:user, company_id: document.company_id)
        create(:paperwork_template, :template_skips_validate, document_id: document.id, company_id: document.company_id, representative_id: representative.id)
      end
    end

    factory :document_with_paperwork_request_and_template do
      after(:create) do |document|
        create(:paperwork_template, :template_skips_validate, document_id: document.id)
        create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: create(:sarah, email: Faker::Internet.email, personal_email: Faker::Internet.email, company: document.company).id)
      end
    end

    factory :document_with_drafted_paperwork_template do
      after(:create) do |document|
        create(:paperwork_template, :template_skips_validate, document_id: document.id, company_id: document.company_id, state: 'draft')
      end
    end
  end
end
