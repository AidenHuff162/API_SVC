module OffBoard
  class ReassignTaskUserConnectionsJob < ApplicationJob
    queue_as :default
    def perform(data, notify_new_owners)
      return if !data
      mail_data = []
      data.each do |task_owner_id|
        if task_owner_id[2] == true
          task = TaskUserConnection.find_by(id: task_owner_id[0])
          task.destroy if task.present?
        else
          task = TaskUserConnection.find_by(id: task_owner_id[0])
          if task.present? && task.owner_id != task_owner_id[1]
            task.owner_id = task_owner_id[1]
            task.save!
            if notify_new_owners
              mail = mail_data.select { |mail| mail[0] == task_owner_id[1]}
              if mail && mail.length > 0
                mail_data.map! { |x| x[0] == task_owner_id[1] ? [task_owner_id[1] , x[1].to_i+1] : x }
              else
                mail_data.push([task_owner_id[1],1])
              end
            end
          end
        end
      end
      if notify_new_owners
        mail_data.each do |mail|
          UserMailer.new_tasks_email(User.find_by(id: mail[0]), nil, nil, mail[1], nil, nil, nil, nil, nil, nil, false, true).deliver_now!
        end
      end
    end
  end
end
