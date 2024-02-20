# namespace :production_data_fix do
#   task adding_namely_group_type_to_missing_teams_in_namely: :environment do
#     company = Company.find_by_subdomain('circleci')
#     namelyGroupType = company.teams.first.namely_group_type

#     company.teams.where(name: ['Engineering ', 'Marketing ']).each do |team|
#         team.namely_group_type = namelyGroupType
#         team.save!
#     end
#   end
# end
