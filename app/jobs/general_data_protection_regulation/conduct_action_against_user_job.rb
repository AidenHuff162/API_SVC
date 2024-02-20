class GeneralDataProtectionRegulation::ConductActionAgainstUserJob < ApplicationJob
  queue_as :manage_general_data_protection_regulation

  def perform(user_id)
    GdprService::GdprManagement.new(User.find_by(id: user_id)).perform
  end
end
