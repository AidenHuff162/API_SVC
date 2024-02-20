FactoryGirl.define do
  factory :workspace_image do
    image File.open('app/assets/images/workspace/cake.svg')
  end

  factory :workspace_image2, parent: :workspace_image do
  	image File.open('app/assets/images/workspace/city.svg')
  end
end
