module PostMigration
  class PostSidekiqMigrationJob
    include Sidekiq::Worker
    sidekiq_options queue: :post_sidekiq_job, retry: false, backtrace: true

    def perform(company_id)
      sidekiq_jobs_data = SidekiqJob.where(company_id: company_id).pluck(:job_name, :job_params, :start_time)
      sidekiq_jobs = sidekiq_jobs_data.map { |data| { job_name: data[0], job_params: data[1], start_time: data[2] } }

      sidekiq_jobs.each do |job|
        case job[:job_name]
        when 'Sidekiq::Extensions::DelayedMailer'
          schedule_delayed_mailer(job)
        when 'SlackIntegrationJob'
          schedule_slack_integration_job(job)
        when 'SendGsuiteCredentialsJob'
          schedule_gsuite_credential_job(job)
        when 'Okta::SendEmployeeToOktaJob', 'SendEmployeeToOktaJob'
          schedule_okta_job(job)
        when 'CreateTaskOnJiraJob'
          schedule_task_on_jira_job(job)
        when 'SendAdfsCredentialsJob'
          schedule_adfs_credential_job(job)
        when 'TimeOff::UpdatePtoRequestsBalanceByUser'
          schedule_pto_balance_update_job(job)
        end
      end
    end

    private

    def schedule_delayed_mailer(job)
      params = job[:job_params]
      return if params.blank?

      user_email = UserEmail.find_by(id: params[0])
      Interactions::UserEmails::ScheduleCustomEmail.new(user_email, params[1], params[2], params[3], params[4]).perform
    end

    def schedule_slack_integration_job(job)
      params = job[:job_params]
      return if params.blank?

      SlackIntegrationJob.perform_at(params[0], params[1], params[2])
    end

    def schedule_gsuite_credential_job(job)
      params = job[:job_params]
      return if params.blank?

      SendGsuiteCredentialsJob.perform_at(params[0], params[1])
    end

    def schedule_okta_job(job)
      params = job[:job_params]
      return if params.blank?

      Okta::SendEmployeeToOktaJob.perform_at(params[0])
    end

    def schedule_task_on_jira_job(job)
      params = job[:job_params]
      return if params.blank?

      CreateTaskOnJiraJob.perform_at(params[0], params[1])
    end

    def schedule_adfs_credential_job(job)
      params = job[:job_params]
      return if params.blank?

      SendAdfsCredentialsJob.perform_at(params[0], params[1])
    end

    def schedule_pto_balance_update_job(job)
      params = job[:job_params]
      return if params.blank?

      TimeOff::UpdatePtoRequestsBalanceByUser.perform_at(params[0])
    end
  end
end
