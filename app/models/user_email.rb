class UserEmail < ApplicationRecord
  has_paper_trail
  acts_as_paranoid
  belongs_to :user
  has_one :invite
  validates :user, presence: true
  belongs_to :editor, class_name: 'User', foreign_key: :editor_id
  has_many :attachments, as: :entity, dependent: :destroy, class_name: 'UploadedFile::Attachment'
  enum status: {scheduled: 0, rescheduled: 1, deleted: 2, completed: 3, incomplete: 4}
  enum send_email: {immediatly: '0', custom_date: '1', relative_key: '2'}
  enum scheduled_from: {offboarding: 0, onboarding: 1, profile: 2, inbox: 3}
  before_destroy :delete_scheduled, if: Proc.new { |user_email| user_email.job_id.present? }

  scope :pre_scheduled_emails, -> (user_ids) { where(user_id: user_ids, email_status: UserEmail.statuses[:scheduled]) }

  # schedule_options attributes description
  # "send_email" => [0,1,2] wrt immediatly, custom date in future and relative to key date
  # "date" => set date if send_email is 1,
  # "time" => set time if send_email is 1,
  # "relative_key" => [start date, last working day, birthday and anniversary]
  # "due" => [on, after, before]
  # "duration_type" => [days, weeks]
  # "duration": numbers

  def completed!
    self.update(email_status: UserEmail::statuses[:completed])
  end

  def deleted!
    delete_scheduled
    self.update(email_status: UserEmail::statuses[:deleted])
  end

  def scheduled!
    self.update(email_status: UserEmail::statuses[:scheduled])
  end

  def assign_template_attachments template_attachments
    if template_attachments.present?
      DuplicateEmailTemplateAttachmentsJob.new.perform(self.id, template_attachments)
      self.update_column(:template_attachments, [])
    end
  end

  def send_user_email(is_daylight_save=nil , flatfile_rehire = false)
    if self.email_type == 'offboarding'
      interaction = Interactions::UserEmails::ScheduleCustomEmail.new(self, true)
      interaction.perform
    else
      interaction = Interactions::UserEmails::ScheduleCustomEmail.new(self, false, is_daylight_save, false, flatfile_rehire)
      interaction.perform
    end
  end

  def get_to_email_list
    emails = []
    user = self.user
    time = self.company_time
    if self.invite_at.nil? && self.email_status == UserEmail::statuses[:completed]
      time = self.sent_at || self.company_time
    elsif self.invite_at.present?
      time = self.time_wrt_company_timezone
    end
    current_time = time.try(:to_date)
    if self.scheduled_from == 'onboarding' || ( user.start_date && user.start_date.try(:to_date) > current_time && user.start_date.try(:to_date) != current_time )
      if !user.onboard_email
        user.email.present? ? emails.push(user.email) : emails.push(user.personal_email)
      elsif user.onboard_email == 'personal'
        emails.push user.personal_email
      elsif user.onboard_email == 'company'
        emails.push user.email
      elsif user.onboard_email == 'both'
        emails.push(user.email) if user.email
        emails.push user.personal_email
      end
    else
      user.email ? emails.push(user.email) : emails.push(user.personal_email)
    end
    emails
  end

  def setup_recipients(to)
    case to
      when "company"
        self.to = [self.user.email]
      when "personal"
        self.to = [self.user.personal_email]
      when "both"
        self.to = [self.user.personal_email,self.user.email]
    end
  end

  def time_wrt_company_timezone
    company = self.user.company
    company_time_zone = company.time_zone ? company.time_zone : 'UTC'
    self.invite_at.present? ? (self.invite_at.to_formatted_s(:db).in_time_zone(company_time_zone)).to_time.utc : nil
  end

  def replace_tokens
    self.description = ReplaceTokensService.new.replace_tokens(self.description, self.user)
    self.subject = ReplaceTokensService.new.replace_tokens(self.subject, self.user)
    self.cc = fetch_email_from_html(ReplaceTokensService.new.replace_tokens(self.cc, self.user))
    self.bcc = fetch_email_from_html(ReplaceTokensService.new.replace_tokens(self.bcc, self.user))
  end

  def fetch_email_from_html string
    if string
      txt = Nokogiri::HTML(string).xpath("//*[p]").first
      txt.content.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i) if txt.present?
    end
  end

  def delete_scheduled
    require 'sidekiq/api'
    Sidekiq::ScheduledSet.new.find_job(self.job_id).try(:delete) if self.job_id.present?
    History.delete_scheduled_email(self.user.histories.find_by(job_id: self.invite.job_id), false) if self.invite.present? && self.invite.job_id.present?
  end

  def set_send_at
    if self.invite_at.nil?  || (self.invite_at + 1.hour) < company_time
      company_time
    else
      self.invite_at
    end
  end

  def company_time
    current_time = self.user.company.time.to_datetime.change(offset: '0')
  end

  def check_valid_schedule_options
    message = nil
    user = self.user
    if ['start date', 'anniversary'].include?(self.schedule_options['relative_key'])
      date = user.start_date.try(:to_date)
      message = 'Set a start date first for this new hire or change the scheduled date' if user.start_date == nil
    elsif self.schedule_options['relative_key'] == 'last day worked'
      if user.last_day_worked == nil
        date = self.schedule_options['last_day_worked'].try(:to_date) if self.scheduled_from == 'offboarding'
        message = "Set last day worked first for this new hire or change the scheduled date" unless date
      else
        date = user.last_day_worked.try(:to_date)
      end
    elsif self.schedule_options['relative_key'] == 'date of termination'
      if user.termination_date == nil
        date = self.schedule_options['termination_date'].try(:to_date) if self.scheduled_from == 'offboarding'
        message = "Set date of termination first for this new hire or change the scheduled date"
      else
        date = user.termination_date.try(:to_date)
      end
    elsif self.schedule_options['relative_key'] == 'birthday'
      if user.date_of_birth == nil
        message = "Set a birth date first for this new hire or change the scheduled date"
      else
        date = user.date_of_birth.try(:to_date)
      end
    end

    if message == nil && self.schedule_options['due'] == 'before'
      date = (date - eval(self.schedule_options["duration"].to_s + '.' + self.schedule_options["duration_type"]) ) if date
    elsif message == nil && self.schedule_options['due'] == 'after'
      date = (date + eval(self.schedule_options["duration"].to_s + '.' + self.schedule_options["duration_type"]) ) if date
    end
    if ['start date', 'last day worked', 'date of termination'].include?(self.schedule_options['relative_key']) && date && date < user.company.time.to_date
      message = 'Selected date is in the past'
    end
    message
  end

  def is_template_exist(template_name, company_id)
    template_name = ActionView::Base.full_sanitizer.sanitize(template_name)
    template_name = "<p>"+template_name+"</p>"
    EmailTemplate.template_exist(template_name, company_id).count > 0 ? true : false
  end
end
