class WeeklyTeamDigestJob
  include Sidekiq::Worker
  sidekiq_options :queue => :weekly_digest, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by(id: company_id)
    if company.present?
      # This job will be execute on firday and we want to send states from Monday to Sunday
      today = Date.today.in_time_zone(company.time_zone).to_date + 3.days
      cutoff_date = today + 6.days
      company.users.where.not("current_stage IN (?) OR state = 'inactive'", [User.current_stages[:incomplete], User.current_stages[:departed], User.current_stages[:offboarding], User.current_stages[:last_month], User.current_stages[:last_week]]).find_each do |user|
        if user.cached_managed_user_ids.present?
          begin
            WeeklyTeamDigestEmailService.new(user).trigger_digest_email(today, cutoff_date)
          rescue Exception => e
            puts '----------------------------------'
            puts "------- Digest Email Faild for User ID #{user.id}--------"
            puts '----------------------------------'
          end
        end
      end
    end
  end

end
