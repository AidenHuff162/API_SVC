FactoryGirl.define do
  factory :user_role do
    name { Faker::Hipster.word }
    description { Faker::Hipster.sentence }
    company
    role_type { Faker::Number.between(0, 3) }

    if [true, false].sample
      locations_array = Array[]
      number_of_locations = (1..5).to_a.sample
      i = 0
      until i < number_of_locations do
        location = create(:location, company: company)
        locations_array.push(location.id.to_s)
      end
      location_permission_level {locations_array}
    else
      location_permission_level { ["all"] }
    end
    permissions { {"platform_visibility":{"profile_info":"view_and_edit","task":"view_and_edit","document":"view_and_edit","calendar":"view_only","time_off":"no_access","updates":"view_and_edit"},"own_info_visibility":{"private_info":"view_and_edit","personal_info":"view_and_edit","additional_info":"view_and_edit"},"employee_record_visibility":{"private_info":"no_access","personal_info":"view_and_edit","additional_info":"view_and_edit"},"admin_visibility":{"dashboard":"view_and_edit","reports":"no_access","records":"no_access","documents":"view_and_edit","tasks":"view_and_edit","general":"view_and_edit","groups":"view_and_edit","emails":"view_and_edit","integrations":"no_access","permissions":"no_access","time_off":"view_only"},"own_role_visibility":{"1":"no_access","2":"no_access","3":"no_access","4":"no_access"},"other_role_visibility":{"1":"view_only","2":"view_only","3":"view_only","4":"view_only"}} }
  end

  factory :admin_role, parent: :user_role do
    role_type 2
    permissions { {"own_platform_visibility":{"profile_info":"view_and_edit", "task":"view_and_edit", "document":"view_and_edit", "calendar":"view_and_edit", "time_off":"view_and_edit", "updates":"view_and_edit"},"platform_visibility":{"profile_info":"view_and_edit","task":"view_and_edit","document":"view_and_edit","calendar":"view_and_edit","time_off":"view_and_edit","updates":"view_and_edit"},"own_info_visibility":{"private_info":"view_and_edit","personal_info":"view_and_edit","additional_info":"view_and_edit"},"employee_record_visibility":{"private_info":"view_and_edit","personal_info":"view_and_edit","additional_info":"view_and_edit"},"admin_visibility":{"dashboard":"view_and_edit","reports":"view_and_edit","records":"view_and_edit","documents":"view_and_edit","tasks":"view_and_edit","general":"view_and_edit","groups":"view_and_edit","emails":"view_and_edit","integrations":"view_and_edit","permissions":"view_and_edit","time_off":"view_and_edit"},"own_role_visibility":{"1":"view_and_edit","2":"view_and_edit","3":"view_and_edit","4":"view_and_edit"},"other_role_visibility":{"1":"view_and_edit","2":"view_and_edit","3":"view_and_edit","4":"view_and_edit"}} }
  end  

  factory :manager, parent: :user_role do
    name "manager"
    role_type 1
    permissions { {"own_platform_visibility":{"profile_info":"no_access", "task":"no_access", "document":"no_access", "calendar":"no_access", "time_off":"view_and_edit", "updates":"no_access"},"platform_visibility":{"profile_info":"no_access","task":"no_access","document":"no_access","calendar":"no_access","time_off":"view_and_edit","updates":"no_access"},"own_info_visibility":{"private_info":"no_access","personal_info":"no_access","additional_info":"no_access"},"employee_record_visibility":{"private_info":"no_access","personal_info":"no_access","additional_info":"no_access"},"admin_visibility":{"dashboard":"no_access","reports":"no_access","records":"no_access","documents":"no_access","tasks":"no_access","general":"no_access","groups":"no_access","emails":"no_access","integrations":"no_access","permissions":"no_access","time_off":"no_access"},"own_role_visibility":{"1":"no_access","2":"no_access","3":"no_access","4":"no_access"},"other_role_visibility":{"1":"no_access","2":"no_access","3":"no_access","4":"no_access"}} }
  end
  factory :with_no_access_for_all, parent: :user_role do
    permissions { {"own_platform_visibility":{"profile_info":"no_access", "task":"no_access", "document":"no_access", "calendar":"no_access", "time_off":"no_access", "updates":"no_access"},"platform_visibility":{"profile_info":"no_access","task":"no_access","document":"no_access","calendar":"no_access","time_off":"no_access","updates":"no_access"},"own_info_visibility":{"private_info":"no_access","personal_info":"no_access","additional_info":"no_access"},"employee_record_visibility":{"private_info":"no_access","personal_info":"no_access","additional_info":"no_access"},"admin_visibility":{"dashboard":"no_access","reports":"no_access","records":"no_access","documents":"no_access","tasks":"no_access","general":"no_access","groups":"no_access","emails":"no_access","integrations":"no_access","permissions":"no_access","time_off":"no_access"},"own_role_visibility":{"1":"no_access","2":"no_access","3":"no_access","4":"no_access"},"other_role_visibility":{"1":"no_access","2":"no_access","3":"no_access","4":"no_access"}} }
  end

  factory :with_view_access_for_all, parent: :user_role do
    permissions { {"own_platform_visibility":{"profile_info":"view_only", "task":"view_only", "document":"view_only", "calendar":"view_only", "time_off":"view_only", "updates":"view_only"},"platform_visibility":{"profile_info":"view_only","task":"view_only","document":"view_only","calendar":"view_only","time_off":"view_only","updates":"view_only"},"own_info_visibility":{"private_info":"view_only","personal_info":"view_only","additional_info":"view_only"},"employee_record_visibility":{"private_info":"view_only","personal_info":"view_only","additional_info":"view_only"},"admin_visibility":{"dashboard":"view_only","reports":"view_only","records":"view_only","documents":"view_only","tasks":"view_only","general":"view_only","groups":"view_only","emails":"view_only","integrations":"view_only","permissions":"view_only","time_off":"view_only"},"own_role_visibility":{"1":"view_only","2":"view_only","3":"view_only","4":"view_only"},"other_role_visibility":{"1":"view_only","2":"view_only","3":"view_only","4":"view_only"}} }
  end

  factory :with_view_and_edit_access_for_all, parent: :user_role do
    permissions { {"own_platform_visibility":{"profile_info":"view_and_edit", "task":"view_and_edit", "document":"view_and_edit", "calendar":"view_and_edit", "time_off":"view_and_edit", "updates":"view_and_edit"},"platform_visibility":{"profile_info":"view_and_edit","task":"view_and_edit","document":"view_and_edit","calendar":"view_and_edit","time_off":"view_and_edit","updates":"view_and_edit"},"own_info_visibility":{"private_info":"view_and_edit","personal_info":"view_and_edit","additional_info":"view_and_edit"},"employee_record_visibility":{"private_info":"view_and_edit","personal_info":"view_and_edit","additional_info":"view_and_edit"},"admin_visibility":{"dashboard":"view_and_edit","reports":"view_and_edit","records":"view_and_edit","documents":"view_and_edit","tasks":"view_and_edit","general":"view_and_edit","groups":"view_and_edit","emails":"view_and_edit","integrations":"view_and_edit","permissions":"view_and_edit","time_off":"view_and_edit"},"own_role_visibility":{"1":"view_and_edit","2":"view_and_edit","3":"view_and_edit","4":"view_and_edit"},"other_role_visibility":{"1":"view_and_edit","2":"view_and_edit","3":"view_and_edit","4":"view_and_edit"}} }
  end
end
