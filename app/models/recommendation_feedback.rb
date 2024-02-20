class RecommendationFeedback < ApplicationRecord
  belongs_to :recommendation_user, class_name: 'User'
  belongs_to :recommendation_owner, class_name: 'User'

  enum item_type: { workflow: 0, profile_template: 1 }
  enum process_type: { Onboarding: 0, Offboarding: 1, Relocation: 2, Promotion: 3, Other: 4 }
  enum item_action: { added: 0, removed: 1, both: 2 }
  enum change_reason: { normal_process_exception: 0, account_configuration: 1, stop_recommendation: 2, other_reason: 3 }

end
