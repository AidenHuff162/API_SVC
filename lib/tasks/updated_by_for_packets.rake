namespace :packets do

  desc "Set updated by of packets"
  task updated_by: :environment do
    PaperworkPacket.update_all("updated_by_id = user_id")
  puts "Task completed"
  end
end
