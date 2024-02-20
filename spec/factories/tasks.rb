FactoryGirl.define do
  factory :task do
    name { ('a'..'z').to_a.shuffle[0,8].join }
    description { Faker::Hipster.word }
    deadline_in { 7 }
    task_type 'owner'
    time_line 'immediately'
    workstream
    workspace_id :nil
    association :owner, factory: :user

    factory :task_with_sub_tasks do
      after(:create) do |task|
        create(:sub_task, task: task)
      end
    end
  end

  factory :scheduled_task, parent: :task do
    time_line 'later'
    before_deadline_in { -2 }

    trait :with_sub_tasks do
      factory :task_with_sub_tasks do
        after(:create) do |task|
          create(:sub_task, task: task)
        end
      end
    end
  end
end
