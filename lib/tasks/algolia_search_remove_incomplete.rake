namespace :algolia_search do
	desc "remove incomplete users"
	task remove_incomplete: :environment do
	  users = User.where(current_stage: User::current_stages[:incomplete])
		users.find_each do |user|			
			AlgoliaWorker.perform_now(user.id, nil, true)
		end
  puts "Task completed"
  end
end
