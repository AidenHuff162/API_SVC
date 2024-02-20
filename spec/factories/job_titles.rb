FactoryGirl.define do
  factory :job_title do
    name { Faker::Hipster.word }
    company
  end

  factory :adp_us_job_title, parent: :job_title do
    adp_wfn_us_code_value :us_code
  end

  factory :adp_can_job_title, parent: :job_title do
    adp_wfn_can_code_value :can_code
  end
end