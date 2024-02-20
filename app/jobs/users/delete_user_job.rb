module Users
  class DeleteUserJob
    include Sidekiq::Worker
    sidekiq_options :queue => :delete_user, :retry => 0, :backtrace => true
    
    def perform(user_id = nil, current_user_id = nil, current_company_id = nil)
      @current_company = Company.find_by_id(current_company_id)
      
      unless @current_company.present?
        User.unscoped.find_by_id(user_id).update_column(:visibility, true)
        return
      end
      
      @current_user = @current_company&.users.find_by_id(current_user_id)
      @user = @current_company&.users.unscoped.find_by_id(user_id)

      delete_user()
    end

    private

    def delete_user()
      begin
        @user.destroy!
        PushEventJob.perform_later('employee-deleted', @current_user, {
          employee_id: @user[:id],
          employee_name: @user[:first_name] + ' ' + @user[:last_name],
          employee_email: @user[:email],
          company: @current_company[:name]
        })
        
        SlackNotificationJob.perform_later(@current_company.id, {
          username: @current_user.full_name,
          text: I18n.t("slack_notifications.admin_user.deleted", first_name: @user[:first_name], last_name: @user[:last_name])
        })
        
        History.create_history({
          company: @current_company,
          user_id: @current_user.id,
          description: I18n.t("history_notifications.admin_user.deleted", first_name: @user[:first_name], last_name: @user[:last_name])
        })
        trigger_cancel_webhook
      rescue Exception => e
        if @user.present?
          @user.update_column(:visibility, true)
        else
          User.unscoped.find_by_id(user_id).update_column(:visibility, true)
        end
        LoggingService::GeneralLogging.new.create(@current_company, "Delete user from job", {error: e.message, user_id: @user.id})
      end
    end

    def trigger_cancel_webhook
      WebhookEventServices::ManageWebhookEventService.new.initialize_event(@current_company, {event_type: 'onboarding' ,type: 'onboarding', stage: 'cancelled', triggered_for: @user.id, triggered_by: @current_user.id, user_id: @user.id }) if ['invited', 'preboarding', 'pre_start'].include?(@user.current_stage)
    end
  end
end
