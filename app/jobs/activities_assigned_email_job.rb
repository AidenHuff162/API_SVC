class ActivitiesAssignedEmailJob < ApplicationJob

  def perform(user)
    Interactions::Activities::Assign.new(user).perform
  end

end
