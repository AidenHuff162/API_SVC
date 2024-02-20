FactoryGirl.define do
  factory :workspace do
    name { Faker::Hipster.sentence + Time.now.to_i.to_s }
    associated_email { Faker::Internet.email }

    company
    workspace_image

    factory :workspace_with_single_member do
    	after(:create) do |workspace|
    		create(:workspace_member, workspace: workspace)
    	end
    end

    factory :workspace_with_multiple_members do
    	after(:create) do |workspace|
    		24.times do |count|
    			create(:workspace_member, workspace: workspace)
    		end
    		4.times do |count|
    			create(:workspace_member_with_location, workspace: workspace)
    		end
    		create(:workspace_member_with_location, workspace: workspace, member_role: WorkspaceMember.member_roles[:admin])
    	end
    end
  end
end
