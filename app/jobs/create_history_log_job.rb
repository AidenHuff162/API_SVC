class CreateHistoryLogJob < ApplicationJob
    queue_as :log_field_history

    def perform(user_id,description,tempUser_id,field_name)
        begin
            current_user = User.find_by(id: user_id)
            History.create_history({
              company: current_user.company,
              user_id: user_id,
              description: description,
              attached_users: [tempUser_id]
            })
            puts  "======================================================"
            puts  "Logging History FOR User #{current_user.full_name}"
            puts  "Company: #{current_user.company.id}"
            puts  "User_id: #{user_id}"
            puts  "description: #{description}"
            puts  "TempUser_ID: #{tempUser_id}"
            puts  "======================================================"
        rescue Exception => e
            puts "********************************************************"
            p e
            puts "********************************************************"
        end

    end
end