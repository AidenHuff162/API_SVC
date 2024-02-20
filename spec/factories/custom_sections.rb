FactoryGirl.define do
  factory :custom_section do
    section 'additional_fields'
    is_approval_required false
    approval_expiry_time nil

    company
  end 
end
