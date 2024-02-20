class BulkWorkflowAssignmentJob < ApplicationJob
  queue_as :default

  def perform(params, current_user)
    params['user_task_list'].each do |key, array|
      if array.present?
        Interactions::TaskUserConnections::Assign.new(User.find(key),
                                                      array,
                                                      false,
                                                      false,
                                                      params[:due_dates_from],
                                                      current_user.id).perform
        task_ids = []
        array.each do |k|
          task_ids << k['id']
        end
        SendTasksEmailJob.perform_async(User.find(key).id, task_ids) if params[:notify_users]
      end
    end
  end
end
