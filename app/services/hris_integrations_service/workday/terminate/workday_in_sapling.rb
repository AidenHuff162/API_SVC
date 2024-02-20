class HrisIntegrationsService::Workday::Terminate::WorkdayInSapling < ApplicationService
  include HrisIntegrationsService::Workday::Logs

  attr_reader :user, :company, :termination_params, :termination_date, :error_log_params, :helper_object

  delegate :manage_terminated_employment_status_table_snapshot, to: :manage_integration_service

  def initialize(user, termination_params, helper_object)
    @user = user
    @company = user.company # for error logging
    @error_log_params = termination_params
    @termination_date = termination_params[:termination_date]
    @termination_params = termination_params
    @helper_object = helper_object
  end

  def call
    update_termination_status if termination_date.present?
  end

  private

  def update_termination_status
    begin
      return unless should_terminate?

      if user.company.is_using_custom_table.present?
        manage_terminated_employment_status_table_snapshot(user, termination_params)
      else
        user.tasks.update_all(owner_id: nil)
        user.update_column(:remove_access_timing, 'remove_immediately') if termination_date.to_date < Date.today
        user.update!(updated_user_params)
        user.offboarding!
      end
    rescue Exception => @error
      error_log("Unable to terminate user with id: (#{user&.id}) in Sapling", {}, error_log_params)
    end
  end

  def manage_integration_service
    IntegrationsService::ManageIntegrationCustomTables.new(user.company, nil, 'workday')
  end

  def updated_user_params
    {
      termination_date: termination_date,
      last_day_worked: termination_params[:last_day_worked]
    }
  end

  def should_terminate?
    user&.active? && user.departed?.blank? && user.is_rehired.blank?
  end

end
