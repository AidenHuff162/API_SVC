class Task < ApplicationRecord
  acts_as_paranoid
  has_paper_trail
  belongs_to :owner, class_name: 'User'
  belongs_to :workstream, -> { with_deleted }, counter_cache: true
  belongs_to :workspace
  belongs_to :custom_field
  belongs_to :survey

  has_many :task_user_connections, -> { where.not state: 'draft' }, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy,
                         class_name: 'UploadedFile::Attachment'

  has_many :sub_tasks, dependent: :destroy
  accepts_nested_attributes_for :sub_tasks, allow_destroy: true, reject_if: proc { |attributes| attributes['title'].blank? }

  after_create :update_task_user_connections_for_existing_streams, :if => :updated_from_admin_page
  after_update :update_tasks_connection_with_user, :if => :updated_from_admin_page


  after_create :set_owner_id_as_nil, if: Proc.new { |task| task.task_type != 'owner' && task.owner_id.present? }
  after_update :set_owner_id_as_nil, if: Proc.new { |task| task.task_type != 'owner' && task.owner_id.present? }
  after_save :set_sanitized_title, if: Proc.new { |task| task.name.present? && task.saved_change_to_name? }
  after_update :set_before_deadline_in_as_nil, if: proc { |task| can_set_before_deadline_in_nil?(task) }
  after_update :update_task_in_integration, if: Proc.new { |task| task.saved_change_to_name? || task.saved_change_to_description? }
  before_update :remove_dependent_tasks, if: proc { |task| can_remove_dependent_tasks?(task) }
  after_update :remove_dependent_tucs, if: proc { |task| task.dependent_tasks.empty? }

  after_destroy :reposition_tasks
  after_destroy :remove_dependency_from_connection, if: proc { |task| task.workstream }
  # before_destroy :nullify_associated_data
  attr_accessor :updated_from_admin_tasks, :is_retroactive, :agent_id, :is_survey
  accepts_nested_attributes_for :task_user_connections

  validates :name, :workstream, :deadline_in, presence: true
  validates :owner_id, presence: true, if: :task_type_owner?
  validate :name_uniqueness

  acts_as_list scope: :workstream

  enum task_type: { owner: '0', hire: '1', manager: '2', buddy: '3', jira: '4', workspace: '5', coworker: '6', service_now: '7' }
  enum time_line: { immediately: 0, later: 1, future: 2, dependent: 3, on_due: 4 }

  default_scope { order(position: :asc) }

  # def nullify_associated_data
  #   TaskUserConnection.with_deleted.where(task_id: self.id).update_all(task_id: nil)
  # end

  def name_uniqueness
    if self.workstream_id.present? && self.name.present? && self.workstream.company_id.present?
      if Task.joins(:workstream).where("tasks.name = ? AND tasks.workstream_id = ? AND company_id = ? AND tasks.id != ?", self.name.gsub('\'','\'\'').gsub('\"',''), self.workstream_id, self.workstream.try(:company_id), self.id.to_i).count > 0
        self.errors.add(:base, I18n.t('errors.duplicate_task_name')) if self.will_save_change_to_name?
      end
    end
  end

  def updated_from_admin_page
    self.updated_from_admin_tasks == "true" && self.is_retroactive == "true"
  end

  def set_owner_id_as_nil
    self.update_column :owner_id, nil
  end

  def assign_from_due_date
    @from_due_date.present? ? @from_due_date : Date.today
  end

  def set_before_deadline_in_as_nil
    update_column(:before_deadline_in, 0)
  end

  def update_task_user_connections_for_existing_streams
    workstream_tasks = self.workstream.tasks.pluck(:id)
    User.joins(:task_user_connections).where(task_user_connections: {task_id: workstream_tasks }).group(:id).find_each do |user|
      owner_id = user.id
      if !user.onboarding?
        next
      end

      owners_manager = user.manager
      owners_buddy = user.buddy
      @from_due_date = user.task_user_connections.where(task_id: workstream_tasks).pluck(:from_due_date).first

      if user.incomplete? || user.invited?
        date = if user.start_date then user.start_date else assign_from_due_date end
      elsif user.offboarding? || user.departed?
        date = if user.last_day_worked then user.last_day_worked else assign_from_due_date end
      else
        date = assign_from_due_date
      end

      before_deadline_in = ['immediately', 'dependent'].include?(time_line) ? nil : (date + self.before_deadline_in)
      if self.task_type == "owner"
        if user.active? && user.onboarding?
          self.task_user_connections.create(user_id: owner_id, owner_id: self.owner_id, due_date: date + self.deadline_in, from_due_date: @from_due_date, before_due_date: before_deadline_in, schedule_days_gap: self.before_deadline_in, agent_id: self.agent_id)
          send_retroactive_task_email(owner_id, self.id)
        end

      elsif self.task_type == "hire"
        if user.active? && user.onboarding?
          self.task_user_connections.create(user_id: owner_id, owner_id: owner_id, due_date: date + self.deadline_in, from_due_date: @from_due_date, before_due_date: before_deadline_in, schedule_days_gap: self.before_deadline_in, agent_id: self.agent_id)
          send_retroactive_task_email(owner_id, self.id)
        end

      elsif self.task_type == "manager"
        if user.active? && owners_manager.present? && owners_manager.active?
          self.task_user_connections.create(user_id: owner_id, owner_id: owners_manager.id, due_date: date + self.deadline_in, from_due_date: @from_due_date, before_due_date: before_deadline_in, schedule_days_gap: self.before_deadline_in, agent_id: self.agent_id)
          send_retroactive_task_email(owner_id, self.id)
        end

      elsif self.task_type == "buddy"
        if user.active? && owners_buddy.present? && owners_buddy.active?
          self.task_user_connections.create(user_id: owner_id, owner_id: owners_buddy.id, due_date: date + self.deadline_in, from_due_date: @from_due_date, before_due_date: before_deadline_in, schedule_days_gap: self.before_deadline_in, agent_id: self.agent_id)
          send_retroactive_task_email(owner_id, self.id)
        end

      elsif self.task_type == "workspace"
        if self.workspace_id.present?
          self.task_user_connections.create(user_id: owner_id, owner_id: owner_id, due_date: date + self.deadline_in, from_due_date: @from_due_date, before_due_date: before_deadline_in, schedule_days_gap: self.before_deadline_in, agent_id: self.agent_id, workspace_id: self.workspace_id, owner_type: 'workspace')
        end
      end
    end
  end

  def update_tasks_connection_with_user
    if self.saved_change_to_deadline_in?
      self.task_user_connections.each do |tuc|
        if tuc.user.last_day_worked
          before_deadline_in = set_before_deadline_in(tuc.user.last_day_worked)
          tuc.update_columns(due_date: tuc.user.last_day_worked + self.deadline_in, before_due_date: before_deadline_in, schedule_days_gap: self.before_deadline_in)
        else
          before_deadline_in = set_before_deadline_in(tuc.user.start_date)
          tuc.update_columns(due_date: tuc.user.start_date + self.deadline_in, before_due_date: before_deadline_in, schedule_days_gap: self.before_deadline_in)
        end
      end
    elsif self.task_type == "owner" and self.saved_change_to_owner_id?
      if self.workstream.company
        user = self.workstream.company.users.find_by_id(self.owner_id)
      end
      if user.onboarding? && user.active?
        self.task_user_connections.update_all(owner_id: self.owner_id)
      end
    elsif self.saved_change_to_task_type?
      if self.task_type == "manager"
        self.task_user_connections.each do |tuc|
          manager = tuc.user.manager
          if manager.present? && manager.active?
            tuc.update_column(:owner_id, manager.id)
          end
        end
      elsif self.task_type == "buddy"
        self.task_user_connections.each do |tuc|
          buddy = tuc.user.buddy
          if buddy.present? && buddy.active?
            tuc.update_column(:owner_id, buddy.id)
          end
        end
      elsif self.task_type == "hire"
        self.task_user_connections.each do |tuc|
          user = tuc.user
          if user.onboarding? && user.active?
            tuc.update_column(:owner_id, tuc.user_id)
          end
        end
      end
    end
  end

  def reposition_tasks
    Task.with_advisory_lock('reposition_tasks') do
      if self.workstream
        task_position = self.position + 1
        tasks = self.workstream.tasks.order(:position).where('position > ?', self.position)
        tasks.each do |t|
          t.position = task_position
          t.save(validate: false) #Some existing tasks have the same name but now we introduce the uniq name contraints in validation
          task_position += 1
        end
      end
    end
  end

  def remove_dependent_tasks
    update(dependent_tasks: [])
  end

  def remove_dependent_tucs
    task_user_connections.update_all(dependent_tuc: [])
  end

  def remove_dependency_from_connection
    DeleteDependentTasksJob.perform_later(id, workstream)
  end

  def set_sanitized_title
    self.update_column(:sanitized_name, Nokogiri::HTML(self.name).text) if self.name.present?
  end

  def update_task_in_integration
    if self.jira?
      UpdateTasksOnJiraJob.set(wait: 10.seconds).perform_later(self.id)
    elsif self.service_now?
      Productivity::ServiceNow::UpdateTasksOnServiceNowJob.set(wait: 10.seconds).perform_later(self.workstream&.company_id, self.id)
    end
  end

  def is_task_due_immediately?
    self.deadline_in == 0 && self.task_schedule_options["due_date_relative_key"] == nil && self.task_schedule_options["due_date_custom_date"] == nil && self.task_schedule_options["due_date_timeline"] == nil
  end

  private
  def task_type_owner?
    task_type == 'owner'
  end

  def can_set_before_deadline_in_nil?(task)
    task.saved_change_to_time_line? && ['immediately', 'dependent'].include?(task.time_line)
  end

  def set_before_deadline_in(date)
    if ['immediately', 'dependent'].include?(time_line)
      nil
    else
      date + deadline_in + before_deadline_in
    end
  end

  def can_remove_dependent_tasks?(task)
    task.saved_change_to_time_line? && dependent_tasks.present? && time_line != 'dependent'
  end

  def send_retroactive_task_email(user_id, task_id)
    SendTasksEmailJob.new.perform(user_id, [task_id], false)
  end
end
