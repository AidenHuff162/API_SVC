class TaskUserConnection < ApplicationRecord
  attr_accessor :agent_id, :sub_task_state, :created_through_onboarding

  include CalendarEventsCrudOperations, SubTaskManagement, UserStatisticManagement
  acts_as_paranoid
  has_paper_trail

  belongs_to :user, -> { with_deleted }
  counter_culture :user, column_name: :tasks_count
  counter_culture :user, column_name: proc {|model| (model.in_progress? && model.owner && model.deleted_at.nil?) ? 'outstanding_tasks_count' : nil }

  belongs_to :task, -> { with_deleted }
  has_one :task_owner, through: :task, source: :owner
  belongs_to :owner, -> { with_deleted }, class_name: 'User', foreign_key: :owner_id
  counter_culture :owner, column_name: proc {|model| (model.in_progress? && model.user && model.task.present? && model.task.task_type != 'jira' && model.task.task_type != 'service_now') ? 'outstanding_owner_tasks_count' : nil }
  belongs_to :workspace

  has_many :calendar_events, as: :eventable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :activities, as: :activity, dependent: :destroy
  has_many :sub_task_user_connections, dependent: :destroy
  has_many :survey_answers, dependent: :destroy
  has_many :sub_tasks, through: :sub_task_user_connections

  validates :user, :task, presence: true

  before_create :generate_token
  before_destroy :destroy_integration_task

  after_create :add_assignee_activity
  after_create :create_sub_task_connections
  after_create {|action| action.setup_calendar_event(self, 'task_due_date', self.owner.try(:company))}
  after_update :update_integration_task_state
  after_update :add_state_activity, if: Proc.new { |tuc| tuc.saved_change_to_state? && tuc.state_before_last_save != 'draft' }
  after_update :add_duedate_activity, if: :saved_change_to_due_date?
  after_update :notify_activity, if: :saved_change_to_due_date?
  after_update :add_reassignee_activity, if: :saved_change_to_owner_id?
  after_update :add_completed_by_activity, if: Proc.new { |tuc| tuc.saved_change_to_state? && tuc.completed_by_method == "add_on" }
  after_update do
    if task_due_date_changed? && self.in_progress? && self.user.active?
      update_objects_date_range(self, 'task_due_date', 'due_date')
      Sidekiq::ScheduledSet.new.find_job(self.job_id)&.delete
      create_updated_job if !overdue?
    end
  end
  after_update :change_sub_task_states_to_in_progress, if: Proc.new { |tuc| tuc.saved_change_to_state? && tuc.state == "in_progress" && tuc.sub_task_state.present?}
  after_update :change_sub_task_states_to_completed, if: Proc.new { |tuc| tuc.saved_change_to_state? && tuc.state == "completed" }
  after_update :update_completed_dependent_task, if: proc { |tuc| can_update_completed_dependent_task?(tuc) }
  after_update :assign_dependent_tasks, if: proc { |tuc| tuc.saved_change_to_state? && tuc.state == 'completed' }
  after_update :update_assign_date, if: proc { |tuc| update_assign_date?(tuc) }
  after_create :change_state_from_draft_to_in_progress, unless: proc { |tuc| can_change_state?(tuc) }
  after_destroy :manage_dependent_tasks
  #ROI email management
  after_commit :set_task_completion_date, on: [:create, :update], if: Proc.new { |tuc| tuc.completed? }

  #ROI email management, commented for v2
  # scope :company_based, -> (company_id){ joins(:user).where('users.company_id = ?', company_id) }
  scope :span_based_assigned_tasks, -> (company_id, begin_date, end_date){ joins(:user).where('users.company_id = ? AND DATE(task_user_connections.created_at) >= ? AND DATE(task_user_connections.created_at) <= ?', company_id, begin_date, end_date) }
  # scope :span_based_completed_tasks, -> (company_id, begin_date, end_date){ joins(:user).where('users.company_id = ? AND task_user_connections.completion_date IS NOT NULL AND DATE(task_user_connections.completion_date) >= ? AND DATE(task_user_connections.completion_date) <= ?
  #   AND task_user_connections.state = ?', company_id, begin_date, end_date, 'completed') }
  # scope :span_based_pending_tasks, -> (company_id, begin_date, end_date){ joins(:user).where('users.company_id = ? AND task_user_connections.due_date IS NOT NULL AND DATE(task_user_connections.due_date) >= ? AND DATE(task_user_connections.due_date) <= ?
  #   AND task_user_connections.state = ?', company_id, begin_date, end_date, 'in_progress') }
  scope :incomplete_tasks, -> (company_id, user_id){ joins(:user).where('users.company_id = ? AND task_user_connections.owner_id = ? AND task_user_connections.state = ?', company_id, user_id, 'in_progress').order(due_date: :asc) }
  scope :draft_connections, -> { where state: :draft }
  scope :in_progress_connections, -> { where state: :in_progress }
  scope :independent_connections, -> { where dependent_tuc: [] }
  scope :buddy_tasks, -> { joins(:task).where('tasks.task_type = ?', Task.task_types[:buddy]) }
  scope :having_company, -> (company_id){ joins(task: :workstream).where("workstreams.company_id = ?", company_id) }
  scope :unassigned_service_now_tasks, -> (tuc_id, user_id) { joins(:task).where('task_user_connections.id IN (?) AND user_id = ? AND service_now_id IS NULL AND tasks.task_type = ?', tuc_id, user_id, Task.task_types[:service_now]) }
  
  enum owner_type: { individual: 0, workspace: 1 }
  enum completed_by_method: { other: 0, user: 1, email: 2, asana: 3, add_on: 4, jira: 5, slack: 6 , service_now: 7}

  state_machine :state, initial: :draft do
    event :in_progress do
      transition draft: :in_progress
    end
    event :complete do
      transition in_progress: :completed
    end
  end

  def overdue?
    self.due_date < Date.today && self.in_progress?
  end

  def mark_task_completed
    self.state = "completed"
    self.save!
  end

  def update_jira_issue_state
    UpdateTaskStateOnJiraJob.set(wait: 10.seconds).perform_later(self.id)
  end

  def destroy_jira_issue
    DestroyTaskOnJiraJob.perform_later(self.jira_issue_id, self.task.workstream.company_id) if self.jira_issue_id && self.task.workstream.present?
  end

  def update_service_now_state
    Productivity::ServiceNow::UpdateTaskStateOnServiceNowJob.set(wait: 10.seconds).perform_later(self.task.workstream.company_id, self.id) if self.service_now_id && self.task.workstream.present?
  end

  def destroy_service_now_task
    Productivity::ServiceNow::DestroyTaskOnServiceNowJob.perform_later(self.task.workstream.company_id, self.service_now_id) if self.service_now_id && self.task.workstream.present?
  end

  def destroy_integration_task
    return unless self.task.present?

    destroy_jira_issue if self.task.task_type == 'jira'
    destroy_asana_task if self.asana_id.present?
    destroy_service_now_task if self.task.task_type == 'service_now'
  end

  def update_integration_task_state
    return unless self.task.present?

    update_jira_issue_state if self.task.task_type == 'jira' && self.state == "completed"
    complete_asana_task if self.asana_id.present? && self.state == "completed"
    update_service_now_state if self.task.task_type == 'service_now' && self.state == "completed"
  end

  def generate_token
    self.token = SecureRandom.urlsafe_base64(nil, false)
  end

  def sanitized_title
    self.task.sanitized_title
  end

  def get_cached_comments_count
    Rails.cache.fetch([self.id, 'tuc_comments_count'], expires_in: 2.days) do
      self.comments.count
    end
  end

  def is_sub_task_in_progress?
    Rails.cache.fetch([self.id, 'sub_tuc_in_progress'], expires_in: 2.hours) do
      self.sub_task_user_connections.exists?(state: 'in_progress')
    end
  end

  def expire_sub_task_status
    Rails.cache.delete([self.id, 'sub_tuc_in_progress'])
    true
  end

  def complete_asana_task
    CompleteTaskOnAsanaJob.perform_async(self.id)
  end

  def destroy_asana_task
    AsanaService::DestroyTask.new(self).perform
  end

  def get_survey_report_values(column_headers)
    task_user = self.user
    task_owner = self.owner
    survey = self.task&.survey
    values = []
    column_headers.each do |column_header|
      if column_header == "receiver_user_id"
        values << handle_csv_values(task_user.id)
      elsif column_header == "receiver_first_name"
        values << handle_csv_values(task_user.first_name)
      elsif column_header == "receiver_last_name"
        values << handle_csv_values(task_user.last_name)
      elsif column_header == "receiver_company_email"
        values << handle_csv_values(task_user.email)
      elsif column_header == "owner_user_id"
        values << handle_csv_values(task_owner.id)
      elsif column_header == "owner_first_name"
        values << handle_csv_values(task_owner.first_name)
      elsif column_header == "owner_last_name"
        values << handle_csv_values(task_owner.last_name)
      elsif column_header == "owner_company_email"
        values << handle_csv_values(task_owner.email)
      elsif column_header == "survey_name"
        values << handle_csv_values(survey&.name)
      elsif column_header == "survey_sent_at"
        if self.before_due_date.present?
          values << handle_csv_values(TimeConversionService.new(task_user.company).perform(self.before_due_date))
        else
          values << handle_csv_values(TimeConversionService.new(task_user.company).perform(self.created_at))
        end
      elsif column_header == "survey_completed_at"
        values << handle_csv_values((self.completed? ? TimeConversionService.new(task_user.company).perform(self.completed_at) : ""))
      elsif column_header.integer?
        values << "" if survey.nil?
        question = survey.survey_questions.find_by(id: column_header)
        answer = self.survey_answers.with_deleted.find_by(survey_question_id: question.id)
        if answer.nil?
          values << ""
        elsif question.likert?
          values << handle_csv_values({ 0 => "Strongly Disagree", 1 => "Disagree", 2 => "Neutral", 3 => "Agree", 4 => "Strongly Agree" }[answer.value_text.to_i])
        elsif question.person_lookup?
          values << task_user.company.users.where(id: answer.selected_user_ids).map { |u| "#{u.display_name} (#{u.email || u.personal_email})" }.join("; ")
        else
          values << handle_csv_values(answer.value_text)
        end
      end
    end
    values
  end

  def self.un_processed_jira_tasks(user_id, task_ids)
    task_user_connections = TaskUserConnection.where(user_id: user_id, jira_issue_id: nil).where.not(state: :draft).joins(:task).where('tasks.task_type = ?', Task.task_types[:jira])
    if task_ids && task_ids.length > 0 && task_ids.is_a?(Array) && task_ids.exclude?('all')
      task_user_connections = task_user_connections.where('tasks.id IN (?)', task_ids)
    end

    task_user_connections.pluck(:id)
  end

  def self.un_processed_service_now_tasks(user_id, task_ids)
    task_user_connections = TaskUserConnection.where(user_id: user_id, service_now_id: nil).where.not(state: :draft).joins(:task).where('tasks.task_type = ?', Task.task_types[:service_now])
    if task_ids && task_ids.length > 0 && task_ids.is_a?(Array) && task_ids.exclude?('all')
      task_user_connections = task_user_connections.where('tasks.id IN (?)', task_ids)
    end

    task_user_connections.pluck(:id)
  end

  def get_task_name
    token_service.replace_tokens(self.task.name, self.user, nil, nil, nil, true)
  end

  def get_task_description
    token_service.replace_tokens(self.task.description , self.user , nil , nil, nil, true)
  end

  def token_service
    @token_service ||= ReplaceTokensService.new
  end

  private

  def set_task_completion_date
    completion_date = self.completed? ? Time.now.in_time_zone(self.user&.company&.time_zone).to_date : nil
    self.update_column(:completion_date, completion_date)
  end

  def task_due_date_changed?
    self.saved_changes.keys.include? 'due_date'
  end

  def add_state_activity
    self.update_column(:completed_at, Time.now.in_time_zone(self.user&.company&.time_zone)) if self.completed?
    description = self.completed? ? 'completed the task' : 're-opened the task'
    if self.agent_id.present?
      self.activities.create!(agent_id: self.agent_id, description: description)
    elsif self.workspace_id.present? && self.user_id == self.owner_id
      self.activities.create!(workspace_id: self.workspace_id, description: description)
    elsif self.owner_id.present?
      self.activities.create!(agent_id: self.owner_id, description: description)
    elsif self.user_id.present?
      self.activities.create!(agent_id: self.user_id, description: description)
    end
  end

  def add_duedate_activity
    self.activities.create!(agent_id: self.agent_id, description: "set the due date as #{self.due_date.strftime('%b %d, %Y')}") if self.agent_id.present?
  end

  def add_reassignee_activity
    self.activities.create!(agent_id: self.agent_id, description: "re-assigned the task to #{self.owner.try(:display_name)}" ) if self.agent_id.present?
  end

  def add_completed_by_activity
    description = self.completed? ? 'completed the task' : 're-opened the task'
    self.activities.create!(agent_id: self.owner_id, description: "#{description} through the Gmail add-on" ) if self.owner_id.present?
  end

  def add_assignee_activity
    if self.agent_id.present?
      if self.owner_type == 'individual'
        assigne_name = self.owner.try(:display_name) if self.owner_id.present?
      else
        assigne_name = self.workspace.name
      end
      self.activities.create!(agent_id: self.agent_id, description: "assigned the task to #{assigne_name}" )
    end
  end

  def notify_activity
    return unless schedule_days_gap != 0 && self.in_progress? && (due_date + schedule_days_gap.days) <= Date.today

    SendTasksEmailJob.perform_async(user.id, [task_id])
  end

  def create_sub_task_connections
    create_sub_task_user_connections(self)
    self.expire_sub_task_status
  end

  def change_sub_task_states_to_in_progress
    update_sub_task_user_connections_state(self, 'in_progress')
    self.expire_sub_task_status
  end

  def change_sub_task_states_to_completed
    update_sub_task_user_connections_state(self, 'completed')
    self.expire_sub_task_status
  end

  def assign_dependent_tasks
    AssignDependentTasksJob.perform_later(id)
  end

  def update_completed_dependent_task
    tucs = TaskUserConnection.where('? = ANY(dependent_tuc)', id)
    tucs.each do |t|
      t.update_column(:completed_dependent_task_count, (t.completed_dependent_task_count - 1))
    end
  end

  def manage_dependent_tasks
    ManageDependentTasksJob.perform_later(id)
  end

  def self.incomplete_task_count(user_id)
    TaskUserConnection.where("? IN (user_id, owner_id) AND state = ? AND (before_due_date IS NULL OR before_due_date <= ?) AND task_id IS NOT NULL", user_id, 'in_progress', Date.today).count
  end

  def handle_csv_values value
    if value.present?
      if (value[0] == '0' && !value.include?("/")) || value[0] == '+'
        return "'#{value}'"
      else
        return "#{value}"
      end
    else
      return value
    end
  end

  def notify_on; (self.due_date + self.schedule_days_gap)&.in_time_zone(self.user.company.time_zone) end

  def create_updated_job
      message_content = {
                type: 'assign_task',
                tasks: [self.task.as_json],
                due_dates_from: self.due_date
            }
      job_id = SlackIntegrationJob.perform_at(notify_on, 'Task_Assign', { user_id: self.user.id, current_company_id: self.user.company_id, message_content: message_content }) if notify_on
      self.update(job_id: job_id) if job_id
  end

  def change_state_from_draft_to_in_progress
    self.in_progress
  end

  def can_update_completed_dependent_task?(tuc)
    tuc.saved_change_to_state? && tuc.state == 'in_progress' && tuc.state_before_last_save == 'completed'
  end

  def can_change_state?(tuc)
    tuc.created_through_onboarding.present? || tuc.task.dependent_tasks.present?
  end
  
  def update_assign_date
    update_column(:before_due_date, (due_date + task.before_deadline_in))
  end

  def update_assign_date?(tuc)
    tuc.saved_change_to_due_date? && tuc.task.on_due? && tuc.before_due_date && (tuc.before_due_date > Date.current)
  end
end
