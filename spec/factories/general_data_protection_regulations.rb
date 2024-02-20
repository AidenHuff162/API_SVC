FactoryGirl.define do
  factory :general_data_protection_regulation do
    action_type { GeneralDataProtectionRegulation.action_types[:anonymize] }
    action_period 1
    action_location ['all']

    company
  end
end
