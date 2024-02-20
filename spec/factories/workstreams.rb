FactoryGirl.define do
  factory :workstream do
    name { Faker::Hipster.word }
    company
    tasks_count 0
    factory :workstream_with_tasks do
      after(:create) do |workstream|
        create(:task, workstream: workstream)
      end
    end

    factory :workstream_with_tasks_list do
      after(:create) do |workstream|
        create(:task, workstream: workstream)
        create(:task, workstream: workstream)
        create(:task, workstream: workstream)
      end
    end
  end
end
