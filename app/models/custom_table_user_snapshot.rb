class CustomTableUserSnapshot < ApplicationRecord
  acts_as_paranoid
  include CustomTableManagement, UserStatisticManagement

  attr_accessor :terminate_job_execution, :terminate_callback, :ctus_creation, :skip_dispatch_email, :skip_standard_callbacks, :created_through_flatfile, :is_destroyed

  class << self
    attr_accessor :bypass_approval
  end
  has_paper_trail
  has_many :custom_snapshots, dependent: :destroy
  has_many :activities, as: :activity, dependent: :destroy
  has_many :ctus_approval_chains, dependent: :destroy
  belongs_to :edited_by, class_name: 'User'
  belongs_to :user
  belongs_to :custom_table
  belongs_to :requester, class_name: 'User'
  has_many :approval_chains, as: :approvable, dependent: :destroy
  accepts_nested_attributes_for :approval_chains, allow_destroy: true
  accepts_nested_attributes_for :custom_snapshots, allow_destroy: true
  accepts_nested_attributes_for :ctus_approval_chains, allow_destroy: true
  accepts_nested_attributes_for :activities, allow_destroy: true

  enum state: { queue: 0, applied: 1, processed: 2 }
  enum request_state: { denied: 0, requested: 1,  approved: 2 }
  enum integration_type: { adp_integration_us: 0, adp_integration_can: 1, public_api: 2 }

  scope :user_ctus, -> (user_id, custom_table_id){ where(user_id: user_id, custom_table_id: custom_table_id, is_applicable: true)}
  scope :greater_snapshot_exists, ->(user_id, custom_table_id, ctus_effective_date, current_date){ user_ctus(user_id, custom_table_id).where("custom_table_user_snapshots.effective_date > ? AND custom_table_user_snapshots.effective_date <= ?", ctus_effective_date, current_date)}
  scope :process_user_ctus_state, ->(user_id, custom_table_id, effective_date, ctus_id){ user_ctus(user_id, custom_table_id).where("custom_table_user_snapshots.effective_date <= ?", effective_date).where.not(id: ctus_id).update_all(state: CustomTableUserSnapshot.states[:processed])}
  scope :process_approved_user_ctus_state, ->(user_id, custom_table_id, effective_date, ctus_id){ user_ctus(user_id, custom_table_id).where("custom_table_user_snapshots.effective_date <= ? AND request_state = ?", effective_date, CustomTableUserSnapshot.request_states[:approved]).where.not(id: ctus_id).update_all(state: CustomTableUserSnapshot.states[:processed])}
  scope :process_standard_ctus, ->(user_id, custom_table_id, date){user_ctus(user_id, custom_table_id).where("custom_table_user_snapshots.created_at <= ?", date).update_all(state: CustomTableUserSnapshot.states[:processed])}
  scope :queue_user_ctus_state, ->(user_id, custom_table_id, current_date){ user_ctus(user_id, custom_table_id).where("custom_table_user_snapshots.effective_date > ?",  current_date).update_all(state: CustomTableUserSnapshot.states[:queue])}
  scope :get_latest_approved_ctus, ->(user_id, custom_table_id){ user_ctus(user_id, custom_table_id).where(request_state: CustomTableUserSnapshot.request_states[:approved], state: CustomTableUserSnapshot.states[:processed]).order(effective_date: :desc, updated_at: :desc)}
  scope :get_future_termination_based_snapshots, ->(user_id, current_date){ where("user_id = ? AND effective_date > ? AND is_applicable = ?", user_id, current_date, true) }
  scope :del_future_based_termination_snapshots, ->(user_id, current_date){ where("user_id = ? AND effective_date > ? AND is_applicable = ? AND is_terminated = ?", user_id, current_date, true, true) }
  scope :get_previous_approved_ctus, -> (current_ctus_id, user_id, custom_table_id, ctus_effective_date) { user_ctus(user_id, custom_table_id).where('request_state = ? AND effective_date <= ?', CustomTableUserSnapshot.request_states[:approved], ctus_effective_date).order('effective_date DESC') }
  scope :approved_greater_snapshot_exists, ->(user_id, custom_table_id, ctus_effective_date, current_date){ user_ctus(user_id, custom_table_id).where("request_state = ? AND effective_date > ? AND effective_date <= ?", CustomTableUserSnapshot.request_states[:approved], ctus_effective_date, current_date)}
  scope :get_latest_approved_snapshot_to_applied, ->(user_id, custom_table_id, current_date){ user_ctus(user_id, custom_table_id).where("request_state = ? AND effective_date <= ?", CustomTableUserSnapshot.request_states[:approved], current_date).order(effective_date: :desc, updated_at: :desc)}
  scope :get_latest_snapshot_to_applied, ->(user_id, custom_table_id, current_date){ user_ctus(user_id, custom_table_id).where("effective_date <= ?", current_date).order(effective_date: :desc, updated_at: :desc)}
  scope :get_latest_standard_snapshot_to_applied, -> (user_id, custom_table_id){ user_ctus(user_id, custom_table_id).order(updated_at: :desc) }
  scope :get_future_latest_snapshot_to_applied, ->(user_id, custom_table_id, current_date){ user_ctus(user_id, custom_table_id).where("effective_date > ?", current_date).order(effective_date: :asc, updated_at: :desc)}
  scope :get_future_approved_latest_snapshot_to_applied, ->(user_id, custom_table_id, current_date){ user_ctus(user_id, custom_table_id).where("request_state = ? AND effective_date > ?", CustomTableUserSnapshot.request_states[:approved], current_date).order(effective_date: :asc, updated_at: :desc)}
  scope :get_pending_approvals_count, ->(current_company){ joins(:custom_table).where("custom_tables.company_id = ? AND (custom_tables.is_approval_required = TRUE AND custom_table_user_snapshots.request_state = ?)",
        current_company.id, CustomTableUserSnapshot.request_states[:requested]).count }

  after_create :create_ctus_approval_chains, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.request_state.present? && ctus.custom_table.is_approval_required.present? && ctus.requested? && ctus.requester_id.present? }
  after_update :dispatch_request_change_email, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.request_state.present? && ctus.custom_table.is_approval_required.present? && ctus.requested? && ctus.requester_id.present? && CtusApprovalChain.current_approval_chain(ctus.id)[0]&.requested? }

  # after_create :dispatch_request_change_email, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.request_state.present? && ctus.custom_table.is_approval_required.present? && ctus.requested? && ctus.requester_id.present? }
  after_update :dispatch_approved_denied_email, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.request_state.present? && ctus.custom_table.is_approval_required.present? && ctus.saved_change_to_request_state? && ctus.approved? && ctus.requester_id.present? }
  after_destroy :dispatch_approved_denied_email, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.request_state.present? && ctus.custom_table.is_approval_required.present? && ctus.requested? && ctus.requester_id.present? && ctus.user_id.present? && !ctus.skip_dispatch_email}
  after_destroy :really_destroy_ctus_aprroval_chain, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.custom_table.is_approval_required.present? && ctus.request_state.present? }

  after_save :manage_past_timeline_snapshots_without_approval, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.terminate_callback.blank? && (ctus.custom_table.is_approval_required.blank? || CustomTableUserSnapshot.bypass_approval.present?) && ctus.effective_date.present? && ctus.effective_date <= current_date}
  after_save :manage_future_timeline_snapshots_without_approval, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.terminate_callback.blank? && (ctus.custom_table.is_approval_required.blank? || CustomTableUserSnapshot.bypass_approval.present?) && ctus.effective_date.present? && ctus.effective_date > current_date}
  after_destroy :manage_without_approval_timeline_ctus, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && !ctus.terminate_callback.present? && (ctus.custom_table.is_approval_required.blank? || CustomTableUserSnapshot.bypass_approval.present?) && ctus.user_id.present?}

  after_update :manage_with_approval_updated_snapshots, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.terminate_callback.blank? && ctus.custom_table.is_approval_required.present? && ctus.applied? && ctus.approved?}
  after_destroy :manage_with_approval_timeline_ctus, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.terminate_callback.blank? && ctus.custom_table.is_approval_required.present? && ctus.user_id.present?}
  after_update :manage_past_timeline_approved_snapshots, if: Proc.new{ |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.terminate_callback.blank? && ctus.custom_table.is_approval_required.present? && ctus.effective_date <= current_date && ctus.approved?}
  after_update :manage_future_timeline_snapshots_with_approval, if: Proc.new{ |ctus| ctus.custom_table && ctus.custom_table.timeline? && ctus.terminate_callback.blank? && ctus.custom_table.is_approval_required.present? && ctus.effective_date > current_date && ctus.approved? && CustomTableUserSnapshot.user_ctus(user.id, custom_table.id).count > 1}

  after_create :manage_standard_ctus_creation, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.standard? && ctus.skip_standard_callbacks.blank? }
  after_update :manage_standard_ctus_updation, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.standard? && ctus.skip_standard_callbacks.blank? }
  after_destroy :manage_standard_ctus_deletion, if: Proc.new { |ctus| ctus.custom_table && ctus.custom_table.standard? && ctus.user_id.present? && ctus.skip_standard_callbacks.blank?}

  after_update :update_termination_data, if: Proc.new { |ctus| ctus.custom_table && ctus.user_id.present? && ctus.terminated_data.present? }
  
  after_save :create_activity, if: Proc.new { |ctus| ctus.created_through_flatfile }

  validates :state, presence: true
  validates_uniqueness_of :state, scope: [:user_id, :custom_table_id], conditions: -> { where(state: '1') }
  validates :request_state, inclusion: { in: ["requested"] }, on: :create, if: Proc.new {|ctus| ctus.custom_table.is_approval_required.present? && ctus.requester_id.present? && !CustomTableUserSnapshot.bypass_approval.present?}
  validates_with ApprovalStateValidator, if: Proc.new {|ctus| ctus.custom_table.is_approval_required.present? && ctus.requester_id.present? && !CustomTableUserSnapshot.bypass_approval.present?}

  def approvers
    user_data = {}
    user_data["approver_names"] = []
    user_data["approver_ids"] = []
    user_data["approvers_emails"] = []

    if self.request_state.present? && self.custom_table.is_approval_required.present? && self.requester_id.present?
      approval = CtusApprovalChain.current_approval_chain(self.id)[0]
      if approval&.requested?
        if approval.approval_chain.permission?
          if !approval.approval_chain.approval_ids.include? 'all'
            user_roles = self.custom_table.company.user_roles.where(id: approval.approval_chain.approval_ids)
          else
            user_roles = self.custom_table.company.user_roles.all
          end
          user_data["approver_names"].concat user_roles.collect(&:name)
          user_data["approver_ids"].concat user_roles.collect { |user_role| 
            user_role.try(:users).not_inactive_incomplete.pluck(:id) 
          }.flatten
          user_data["approvers_emails"].concat user_roles.collect{ |role| 
            role.users.not_inactive_incomplete.map{ |user| 
              user.email.present? ?  user.email : user.personal_email 
            } 
          }.flatten

          return user_data

        elsif approval.approval_chain.person?
          user = self.custom_table.company.users.find_by(id: approval.approval_chain.approval_ids)
          if user.present? && user.active?
            user_data["approver_names"].push user.try(:display_name)
            user_data["approver_ids"].push user.try(:id)
            user_data["approvers_emails"].push user.email.present? ? user.email : user.personal_email
          end
          return user_data

        elsif approval.approval_chain.manager?
          user = self.user
          if user.present? && user.active?
            manager = user.manager_level(approval.approval_chain.approval_ids[0])
            return nil if manager&.inactive?
            email = manager.try(:email).present? ? manager.try(:email) : manager.try(:personal_email)
            user_data["approver_names"].push manager.try(:display_name)
            user_data["approver_ids"].push manager.try(:id)
            user_data["approvers_emails"].push email

          end
          return user_data

        elsif approval.approval_chain.requestor_manager?
          requestor = self.requester
          if requestor.present? && requestor.active?
            manager = requestor.manager_level(approval.approval_chain.approval_ids[0])
            email = manager.try(:email).present? ? manager.try(:email) : manager.try(:personal_email)
            user_data["approver_names"].push manager.try(:display_name)
            user_data["approver_ids"].push manager.try(:id)
            user_data["approvers_emails"].push email

          end
          return user_data

        elsif approval.approval_chain.coworker?
          approval_id = approval.approval_chain.approval_ids[0]
          user = self.user.get_custom_coworker approval_id

          if user.present? && user.active?
            user_data["approver_names"].push user.try(:display_name)
            user_data["approver_ids"].push user.try(:id)
            user_data["approvers_emails"].push user.try(:email).present? ? user.try(:email) : user.try(:personal_email)
          end
          return user_data

        elsif approval.approval_chain.individual?
          user = self.user
          if user.present? && user.active?
            user_data["approver_names"].push user.try(:display_name)
            user_data["approver_ids"].push user.try(:id)
            user_data["approvers_emails"].push user.try(:email).present? ? user.try(:email) : user.try(:personal_email)
          end
          return user_data
        end
      end
    end
  end

  def access_permission
    custom_tables = PermissionService.new.fetch_accessable_custom_tables(custom_table.company, User.current, user.id)
    custom_tables.map{|a| a.to_i}.include?(custom_table.id)
  end

  def changed_snapshots
    applied_snapshot = custom_table.custom_table_user_snapshots.where(id: 0..self.id, is_applicable: true, user_id: user.id).order(id: :desc).second
    changed_data = []
    has_access = access_permission

    custom_table.custom_fields.each do |field|
      data = {}
      data[:custom_field_name] = field.name
      applied_value = user.get_ctus_field_data(field, applied_snapshot, nil) if applied_snapshot.present?
      new_value = user.get_ctus_field_data(field, self, nil)
      if has_access
        data[:applied_value] = applied_value
        data[:new_value] = new_value
        data[:field_type] = field.field_type
      end
      changed_data.push(data) if applied_value != new_value
    end
    default_fields = []

    if custom_table.role_information?
      default_fields =  custom_table.company.prefrences['default_fields'].select{|a| a['custom_table_property'] == 'role_information'}
    elsif custom_table.employment_status?
      default_fields =  custom_table.company.prefrences['default_fields'].select{|a| a['custom_table_property'] == 'employment_status'}
    end

    default_fields.each do |field|
      data = {}
      data[:custom_field_name] = field['name']
      applied_value = user.get_ctus_field_data(nil, applied_snapshot, field) if applied_snapshot.present?
      new_value = user.get_ctus_field_data(nil, self, field)
      if has_access
        data[:applied_value] = applied_value
        data[:new_value] = new_value
        data[:field_type] = field['field_type']
      end
      changed_data.push(data) if applied_value != new_value
    end

    changed_data
  end

  def find_next_approver
    approval = CtusApprovalChain.current_approval_chain(self.id)[0]
    self.approval_chain_list(false, [approval])[0] if approval&.requested?
  end

  def approval_chain_list(for_email=false, approval_chains=nil)
    custom_table = self.custom_table
    return [] unless custom_table.is_approval_required

    company = custom_table.company
    user = self.user

    approver_list = []
    approver = nil
    index = 0
    denied = false
    approval_chains ||= self.ctus_approval_chains.includes([:approval_chain]).order(:id)

    approval_chains.each do |ctus_chain|
      approver = nil
      approval_chain = ApprovalChain.with_deleted.find_by(id: ctus_chain.approval_chain_id)

      next unless approval_chain.present?

      user_data = {}
      user_data["approver_names"] = ''
      user_data["approver_type"] = ''
      user_data["approver_picture"] = ''
      user_data["approver_status"] = ''
      user_data["approver_initials"] = ''
      user_data["approval_date"] = ''
      user_data["current_approver"] = false
      user_data["index"] = index+=1

      current_chain = CtusApprovalChain.current_approval_chain(self.id)[0]
      user_data["current_approver"] = true if current_chain.present? && ctus_chain.id == current_chain.id

      user_data["approval_date"] = ctus_chain.approval_date&.strftime('%b %d, %Y')

      if ctus_chain.approved?
        user_data["approver_status"] = 'approved'
        approver = company.users.with_deleted.find_by(id: ctus_chain.approved_by_id)
        case approval_chain.approval_type

        when 'person'
          user_data["approver_type"] = approver.try(:title)
        when 'manager'
          user_data["approver_type"] = 'Team Member ' + approval_chain.approval_ids[0].to_i.ordinalize + ' Level Manager'
        when 'requestor_manager'
          user_data["approver_type"] = 'Requestor ' + approval_chain.approval_ids[0].to_i.ordinalize + ' Level Manager'
        when 'coworker'
          approval_id = approval_chain.approval_ids[0]
          user_data["approver_type"] = CustomField.get_coworker_field_name(approval_id)
        end

      else
        approver = User.current if for_email.present? && denied == false && ctus_chain.requested?

        if approver.nil?
          case approval_chain.approval_type

          when 'permission'
            if !approval_chain.approval_ids.include? 'all'
              user_roles = company.user_roles.where(id: approval_chain.approval_ids)
            else
              user_roles = company.user_roles.all
            end
            user_data["approver_names"] = user_roles.collect(&:name).map(&:inspect.to_sym).join(', ').remove('"')
            user_data["approver_type"] = 'Permission Group'
            user_data["approver_initials"] = 'P G'
          when 'person'
            approver = company.users.with_deleted.find_by(id: approval_chain.approval_ids)
            user_data["approver_type"] = approver.try(:title)
          when 'manager'
            approver = user.manager_level(approval_chain.approval_ids[0])
            user_data["approver_type"] = 'Team Member ' + approval_chain.approval_ids[0].to_i.ordinalize + ' Level Manager'
          when 'requestor_manager'
            approver = self.requester.manager_level(approval_chain.approval_ids[0])
            user_data["approver_type"] = 'Requestor ' + approval_chain.approval_ids[0].to_i.ordinalize + ' Level Manager'
          when 'coworker'
            approval_id = approval_chain.approval_ids[0]
            approver = user.get_custom_coworker approval_id
            user_data["approver_type"] = CustomField.get_coworker_field_name(approval_id)
          when 'individual'
            approver = user
          end
        end
      end

      user_data["approver_requested"] = true if ctus_chain.requested?

      if self.requested? && ctus_chain.requested? && for_email.present? && denied == false
        user_data["approver_status"] = 'denied'
        user_data["approver_requested"] = false
        denied = true
      end

      if approval_chain.approval_type != 'permission' || (approval_chain.approval_type == 'permission' && (ctus_chain.approved? || (ctus_chain.requested? && approver.present?)))
        user_data["approver_status"] = 'undefined' if approver.blank? || approver.inactive?
        user_data["approver_names"] = approver.try(:preferred_full_name)
        user_data["approver_picture"] = approver.try(:picture)
        user_data["approver_initials"] = approver.try(:initials)
        user_data["approver_type"] = approver.try(:user_role).try(:name) if (ctus_chain.approved? || (ctus_chain.requested? && approver.present?)) && approval_chain.approval_type == 'permission'
      end

      if for_email.present?
        user_data = map_approver_status(user_data)
      end
      approver_list.push(user_data)
    end

    approver_list
  end

  def dispatch_email_to_approver
    dispatch_request_change_email
  end

  def manage_approval_snapshot_on_user_termination
    approve_or_request
  end

  def create_activity
    self.activities.create(agent_id: self.edited_by_id, description: " has made a change to #{self.custom_table.name}")
  end

  def get_approval_chains
    self.approval_chains.present? ? self.approval_chains : self.custom_table.approval_chains
  end

  private

  def current_date
    DateTime.now.utc.in_time_zone(custom_table.company.time_zone).to_date
  end

  def current_time
    DateTime.now.utc.in_time_zone(custom_table.company.time_zone)
  end

  def manage_past_timeline_approved_snapshots
    if CustomTableUserSnapshot.approved_greater_snapshot_exists(user.id, custom_table.id, effective_date, current_date).blank?
      manage_snapshot_state
    else
      new_applied_ctus = CustomTableUserSnapshot.get_latest_approved_snapshot_to_applied(user.id, custom_table.id, current_date)&.take
      if new_applied_ctus.present?
        CustomTableUserSnapshot.process_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date, new_applied_ctus.id)
        updateStateAndAssignValues(new_applied_ctus)
      end
    end
  end

  def manage_with_approval_updated_snapshots
    assignValuesToUser(self)
  end

  def manage_without_approval_timeline_ctus
    if applied? && user.present? && CustomTableUserSnapshot.user_ctus(user.id, custom_table.id).present?
      future_ctus = CustomTableUserSnapshot.user_ctus(user.id, custom_table.id).where('custom_table_user_snapshots.effective_date > ?', current_date).order(:effective_date, :updated_at)
      past_ctus = CustomTableUserSnapshot.user_ctus(user.id, custom_table.id).where('custom_table_user_snapshots.effective_date <= ?', current_date).order(effective_date: :desc, updated_at: :desc)
      new_applied_ctus = nil

      if effective_date <= current_date
        if past_ctus.present?
          new_applied_ctus = past_ctus.take
        else
          new_applied_ctus = future_ctus.take
        end
      else
        new_applied_ctus = future_ctus.take
      end
      updateStateAndAssignValues(new_applied_ctus) if new_applied_ctus.present?
    end
  end

  def manage_with_approval_timeline_ctus
    if applied? && user.present? && CustomTableUserSnapshot.user_ctus(user.id, custom_table.id).present?
      new_applied_ctus = CustomTableUserSnapshot.get_latest_approved_snapshot_to_applied(user.id, custom_table.id, current_date)&.take
      new_applied_ctus = CustomTableUserSnapshot.get_future_approved_latest_snapshot_to_applied(user.id, custom_table.id, current_date)&.take if new_applied_ctus.blank?

      if new_applied_ctus.present?
          CustomTableUserSnapshot.process_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date, new_applied_ctus.id)
          CustomTableUserSnapshot.queue_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date)
          updateStateAndAssignValues(new_applied_ctus)
      else
        update_columns(state: CustomTableUserSnapshot.states[:queue], updated_at: current_time)
      end
    end
  end

  def manage_past_timeline_snapshots_without_approval
    if custom_table.is_approval_required.blank? || CustomTableUserSnapshot.bypass_approval
      if CustomTableUserSnapshot.greater_snapshot_exists(user.id, custom_table.id, effective_date, current_date).blank?
        manage_snapshot_state
      else
        new_applied_ctus = CustomTableUserSnapshot.get_latest_snapshot_to_applied(user.id, custom_table.id, current_date)&.take
        if new_applied_ctus.present?
          CustomTableUserSnapshot.process_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date, new_applied_ctus.id)
          updateStateAndAssignValues(new_applied_ctus)
        end
      end
    end
  end

  def manage_snapshot_state
    CustomTableUserSnapshot.process_user_ctus_state(user.id, custom_table.id, effective_date, id)
    CustomTableUserSnapshot.queue_user_ctus_state(user.id, custom_table.id, current_date)
    updateStateAndAssignValues
  end

  def manage_future_timeline_snapshots_without_approval
    new_applied_ctus = CustomTableUserSnapshot.get_latest_snapshot_to_applied(user.id, custom_table.id, current_date)&.take
    new_applied_ctus = CustomTableUserSnapshot.get_future_latest_snapshot_to_applied(user.id, custom_table.id, current_date)&.take if new_applied_ctus.blank?
    if new_applied_ctus.present?
      CustomTableUserSnapshot.process_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date, new_applied_ctus.id)
      CustomTableUserSnapshot.queue_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date)
      updateStateAndAssignValues(new_applied_ctus)
    else
      update_columns(state: CustomTableUserSnapshot.states[:queue], updated_at: current_time)
    end
  end

  def manage_future_timeline_snapshots_with_approval
    new_applied_ctus = CustomTableUserSnapshot.get_latest_approved_snapshot_to_applied(user.id, custom_table.id, current_date)&.take
    new_applied_ctus = CustomTableUserSnapshot.get_future_approved_latest_snapshot_to_applied(user.id, custom_table.id, current_date)&.take if new_applied_ctus.blank?
    if new_applied_ctus.present?
        CustomTableUserSnapshot.process_approved_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date, new_applied_ctus.id)
        CustomTableUserSnapshot.queue_user_ctus_state(user.id, custom_table.id, new_applied_ctus.effective_date)
        updateStateAndAssignValues(new_applied_ctus)
    else
      update_columns(state: CustomTableUserSnapshot.states[:queue], updated_at: current_time)
    end
  end

  def manage_standard_ctus_creation
    CustomTableUserSnapshot.process_standard_ctus(user_id, custom_table_id, created_at)
    updateStateAndAssignValues
  end

  def manage_standard_ctus_updation
    assignValuesToUser(self) if applied?
  end

  def manage_standard_ctus_deletion
    ctus = CustomTableUserSnapshot.user_ctus(user_id, custom_table_id).order(created_at: :desc).take
    updateStateAndAssignValues(ctus) if ctus.present?
  end

  def updateStateAndAssignValues(ctus = self)
    return if ctus.applied? && ctus.id != self.id

    ctus.update_columns(state: CustomTableUserSnapshot.states[:applied], updated_at: current_time) if ctus.is_applicable?
    assignValuesToUser(ctus)
  end

  def assignValuesToUser(ctus)
    ::CustomTables::AssignCustomFieldValue.new.assign_values_to_user(ctus) if ctus.applied? && ctus.terminate_job_execution.blank? && ctus.is_applicable?
  end

  def update_termination_data
    user = self.try(:user)
    user.update_column(:last_day_worked, self.terminated_data["last_day_worked"])
    user.update_column(:termination_date, self.effective_date)
    user.send(:update_task_due_dates)
  end

  def dispatch_request_change_email
    custom_table = self.try(:custom_table)
    user_approvers = approvers
    if user_approvers.nil?
      approve_or_request
    else
      effective_date = self.effective_date.strftime('%b %d, %Y') rescue nil
      expiry_time = (self.created_at + custom_table.approval_expiry_time.days).strftime('%b %d, %Y') rescue nil
      if user_approvers.present? && user_approvers['approver_ids'].present?
        user_approvers['approver_ids'].try(:each) do |approver_id|
          UserMailer.ctus_request_change_email_for_approvers(custom_table.try(:company_id), self.try(:requester_id), approver_id, self.user_id, custom_table.try(:name), effective_date, expiry_time).deliver_later!
        end
      else
        approve_or_request
      end
    end
  end

  def approve_or_request
    chain = CtusApprovalChain.current_approval_chain(self.id)[0]
    chain&.update(request_state: CtusApprovalChain.request_states[:skipped])
    next_chain = CtusApprovalChain.current_approval_chain(self.id)[0]
    if next_chain.present?
      dispatch_request_change_email
    else
      auto_approve_request
      dispatch_approved_denied_email
    end
  end

  def dispatch_approved_denied_email
    created_at = self.created_at.strftime('%b %d, %Y') rescue nil
    UserMailer.ctus_request_approved_denied_email_notification(self.try(:custom_table).try(:company_id), created_at, self.user_id, self.requester_id, self.request_state, self.approval_chain_list(true, self.ctus_approval_chains.with_deleted.order(:id)), self.try(:custom_table).name, self.is_destroyed).deliver_later! if self.requested? || self.approved?
  end

  def create_ctus_approval_chains
    approval_chains = self.get_approval_chains
    approval_chains.reorder(id: :asc).try(:each) do |approval_chain|
      self.ctus_approval_chains.create(approval_chain_id: approval_chain.id, request_state: 'requested')
    end
    check_if_requester_exist_in_chain?
  end
end

def logging
  @logging ||= LoggingService::GeneralLogging.new
end

def really_destroy_ctus_aprroval_chain
  self.ctus_approval_chains.with_deleted.delete_all
end

def map_approver_status(data)
  if data["approver_status"] == 'approved'
    data['approver_approved'] = true
  elsif data["approver_status"] == 'denied'
    data['approver_denied'] = true
  elsif data["approver_status"] == 'undefined'
    data['approver_undefined'] = true
  end

  data
end

def check_if_requester_exist_in_chain?
  approver = nil
  approver_present = false
  approval_chains = self.get_approval_chains
  approval_chains.reorder(id: :desc).try(:each_with_index) do |approval_chain, index|
    case approval_chain.approval_type
    when 'person'
      approver = self.custom_table.company.users.find_by(id: approval_chain.approval_ids)
    when 'manager'
      approver = self.user.manager_level(approval_chain.approval_ids[0])
    when 'requestor_manager'
      approver = self.requester.manager_level(approval_chain.approval_ids[0])
    when 'coworker'
      approval_id = approval_chain.approval_ids[0]
      approver = self.user.get_custom_coworker approval_id
    when 'individual'
      approver = self.user
    end

    approver_present = true if approver&.id == self.requester_id
    self.ctus_approval_chains.where(approval_chain_id: approval_chain.id).take.update_column(:request_state, CtusApprovalChain.request_states[:skipped]) if approver_present
  end

  dispatch_request_change_email
end

def auto_approve_request
  logging.create(custom_table.company, 'Auto Approving Request', {custom_snapshot: custom_snapshots, request: "#{custom_table.try(:name)} - AutoApprovingRequest(#{user.id}:#{user.full_name})"}, 'CustomTables')
  update_column(:request_state, CustomTableUserSnapshot.request_states[:approved])
  manage_past_timeline_approved_snapshots if self.effective_date <= current_date
end
