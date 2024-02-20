class UpdateTaskDueDateJob < ApplicationJob
  def perform(user_id, update_activties, update_termination_activities, old_start_date, is_start_date)
    user = User.find_by(id: user_id)
    return unless user.present?
    date = is_start_date ? user.start_date : user.last_day_worked
    old_start_date = Date.parse(old_start_date) rescue nil
    Interactions::Users::UpdateActivitiesDeadline.new(user_id, date, update_activties,
                                                      update_termination_activities, old_start_date).perform
  end
end
