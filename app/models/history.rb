class History < ApplicationRecord
  has_paper_trail
  belongs_to :company
  belongs_to :user
  has_many :history_users, dependent: :destroy
  validates :description, :company_id, presence: true
 
  enum created_by: { user: 0, system: 1 }
  enum event_type: { general: 0, integration: 1, scheduled_email: 2, email: 3 }
  enum is_created: { successful: 0, unsuccessful: 1 }
  enum integration_type: { no_integration: 0, adp: 1 , jira: 2, namely: 3, bamboo: 4, service_now: 5 }
  enum email_type: { no_email: 0, welcome: 1, invite: 2 }

  def self.create_history(params)
    company = params.delete(:company)
    
    if company.histories.last && company.histories.last.description.eql?(params[:description])
      company.histories.last.update_columns(
        description_count: (company.histories.last.description_count+1),
        event_type: History.event_types[:scheduled_email],
        created_at: Time.now,
        email_type: History.email_types[:invite],
        job_id: params[:job_id],
        user_email_id: params[:user_email_id],
        schedule_email_at: params[:schedule_email_at]
        )
    else
      attached_users = params.delete(:attached_users)
      history = company.histories.create!(params)
      attached_users.try(:each) { |attached_user| history.history_users.create!(user_id: attached_user) }
    end
  end

  def self.delete_scheduled_email(history, can_create = true)
    return unless history.present?

    require 'sidekiq/api'
    Sidekiq::ScheduledSet.new.find_job(history.job_id).try(:delete)
    params = history.slice(:company, :created_by, :user_id, :event_type, :email_type).to_h.symbolize_keys
    params[:attached_users] = history.history_users.pluck(:user_id)
    params[:description] = (history.welcome?) ? I18n.t('history_notifications.email.scheduled_welcome_canceled', full_name: history.user.full_name) : I18n.t('history_notifications.email.scheduled_invite_canceled', full_name: history.user.full_name)
    history.user.user_emails.with_deleted.where(email_type: 'welcome_email').first.update_column(:email_status, UserEmail.statuses[:deleted])
    history.update_columns(job_id: nil, event_type: History.event_types[:email], schedule_email_at: nil)
    self.create_history(params) if can_create.present?
  end

  def self.roundTime(granularity=1.hour, time_zone)
    Time.at((DateTime.now.in_time_zone(time_zone).to_time.to_i/granularity).round * granularity).to_datetime
  end

  def self.update_scheduled_email(history, schedule_email_at)    
    schedule_email_at = DateTime.parse(schedule_email_at).to_datetime
    company_time_zone = history.company.time_zone ? history.company.time_zone : 'UTC'
    schedule_time_with_offset = schedule_email_at.utc.change(offset: ActiveSupport::TimeZone[company_time_zone].formatted_offset(false))    
    if history.invite? && history.user
      invite = history.user.invites.find_by(job_id: history.job_id)
    else
      invite = nil
    end
    require 'sidekiq/api'
    if DateTime.now > schedule_time_with_offset
      if history.email_type == 'welcome'
        if history.user
          user_email = history.user.user_emails.find_by_id(history.user_email_id)
          user_email.update_columns(invite_at: self.roundTime(30.minutes, company_time_zone), email_status: UserEmail.statuses[:rescheduled])
        end
      else
        Sidekiq::ScheduledSet.new.find_job(history.job_id).reschedule(Time.now)
        invite.user_email.update_column(:invite_at, schedule_email_at) if schedule_email_at.present? && invite.present?
        invite.update_column(:job_id, nil) if invite.present?
      end
      history.update_columns(job_id: nil, user_email_id: nil, event_type: History.event_types[:email])
    else
      job = Sidekiq::ScheduledSet.new.find_job(history.job_id) if !(history.email_type == 'welcome')
      user_email_id = nil          
      if job
        job.reschedule(schedule_email_at)
      else
        if history.email_type == "welcome"
          if history.user
            user_email = history.user.user_emails.find_by_id(history.user_email_id)
          end
          if user_email
            user_email.update_columns(email_status: UserEmail.statuses[:rescheduled], invite_at: schedule_email_at)
            user_email_id = user_email.id
          end
        end
      end
      new_history = history.deep_clone include: [:history_users], except: [:description, :schedule_email_at]
      new_history.description = (history.welcome?) ? I18n.t('history_notifications.email.welcome_email', full_name: history.user.full_name, time: schedule_email_at.strftime("%B %d at %I:%M%p")) : I18n.t('history_notifications.email.scheduled_invite', full_name: history.user.full_name, time: schedule_email_at.strftime("%B %d at %I:%M%p"))
      new_history.schedule_email_at = schedule_email_at
      new_history.user_email_id = user_email_id if user_email_id
      invite.update_columns(invite_at: schedule_email_at) if invite.present?
      new_history.save
      history.destroy
    end
  end
end
