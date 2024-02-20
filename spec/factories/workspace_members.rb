FactoryGirl.define do
  factory :workspace_member do
    member_role { WorkspaceMember.member_roles[:user] }
    
    workspace
    member { build(:user, company: workspace.company, role: User.roles[:employee])}
  end

  factory :workspace_member_with_location, parent: :workspace_member do
  	member { build(:user_with_location, company: workspace.company, location: create(:location, company: workspace.company))}
  end
end
