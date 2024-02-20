module OffBoard
  class ReassignManagersJob < ApplicationJob
    queue_as :default
    def perform(data, notify_managers, company)
      return if company.is_using_custom_table.present?
      return unless data

      data.each do |user_manager_id|
        user = User.find_by(id: user_manager_id[0], company_id: company.id)
        dup_user = user.dup
        user.manager_id = user_manager_id[1]
        user.notify_new_managers = notify_managers
        user.save!

        IntegrationsService::UserIntegrationOperationsService.new(user, nil, nil, { tmp_user: dup_user })
                          .perform('update', { manager_id: user_manager_id[1] }.with_indifferent_access)
      rescue StandardError => e
        LoggingService::GeneralLogging.new.create(company, 'User - ReassignManagersJob', { error: e.message })
      end
    end
  end
end
