namespace :set_sanitized_titles do
	task set_sanitized_titles: :environment do
    Task.find_each do |task|
      task.update_column(:sanitized_name, Nokogiri::HTML(task.name).text) if task.name.present? && task.owner.present?
    end
	end
end
