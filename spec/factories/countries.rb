FactoryGirl.define do
  factory :country do
    name { Faker::Hipster.word }
    subdivision_type { Faker::Hipster.word }
  end

  factory :argentina, parent: :country do
  	name 'Argentina'
  	key 'AR'
  	subdivision_type 'Province'

  	after(:create) do |country|
      create(:state, key: 'B', name: 'Buenos Aires', country: country)
      create(:state, key: 'C', name: 'Capital federal', country: country)
      create(:state, key: 'K', name: 'Catamarca', country: country)
    end
  end

  factory :australia, parent: :country do
  	name 'Australia'
  	key 'AU'
  	subdivision_type 'State'

  	after(:create) do |country|
      create(:state, key: 'ACT', name: 'Australian Capital Territory', country: country)
      create(:state, key: 'NSW', name: 'New South Wales', country: country)
      create(:state, key: 'NT', name: 'Northern Territory', country: country)
    end
  end

  factory :canada, parent: :country do
  	name 'Canada'
  	key 'CA'
  	subdivision_type 'Province'

  	after(:create) do |country|
      create(:state, key: 'AB', name: 'Alberta', country: country)
      create(:state, key: 'BC', name: 'British Columbia', country: country)
      create(:state, key: 'MB', name: 'Manitoba', country: country)
    end
  end

  factory :united_kingdom, parent: :country do
  	name 'United Kingdom'
  	key 'GB'
  	subdivision_type 'County'

  	after(:create) do |country|
      create(:state, key: 'ABE', name: 'Aberdeen City', country: country)
      create(:state, key: 'ABD', name: 'Aberdeenshire', country: country)
      create(:state, key: 'ANS', name: 'Angus', country: country)
    end
  end

  factory :united_states, parent: :country do
   	name 'United States'
   	key 'US'
    subdivision_type 'State'

    after(:create) do |country|
      create(:state, key: 'AL', name: 'Alabama', country: country)
      create(:state, key: 'AK', name: 'Alaska', country: country)
      create(:state, key: 'AS', name: 'American Samoa', country: country)
    end
  end


  factory :ireland, parent: :country do
    name 'Ireland'
    key 'IR'
    subdivision_type 'County'

    after(:create) do |country|
      create(:state, key: 'CW', name: 'CWN', country: country)
      create(:state, key: 'CN', name: 'CNN', country: country)
      create(:state, key: 'CE', name: 'CEN', country: country)
    end
  end
end