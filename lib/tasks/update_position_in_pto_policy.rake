namespace :update_position_in_pto_policy do
  task pto_position: :environment do
    Company.find_each do |company|
      company.pto_policies.order(:policy_type).each_with_index do |policy,index|
        policy.update_column(:position, index+1)
      end
    end
  end
end