class CustomSectionApproval < ApplicationRecord
  acts_as_paranoid

  attr_accessor :skip_dispatch_email

  belongs_to :custom_section
  belongs_to :user
  belongs_to :requester, class_name: 'User'
  has_many :requested_fields, dependent: :destroy
  has_many :cs_approval_chains, dependent: :destroy
  has_many :approval_chains, as: :approvable, dependent: :destroy

  validates_uniqueness_of :state, scope: [:user_id, :custom_section_id], conditions: -> { where(state: 'requested') }

  accepts_nested_attributes_for :cs_approval_chains, allow_destroy: true

  enum state: { denied: 0, requested: 1, approved: 2, expired: 3 }
  after_update :dispatch_request_change_email, if: Proc.new { |csa| csa.custom_section && csa.state.present? && csa.custom_section.is_approval_required.present? && csa.requested? && csa.requester_id.present? && CsApprovalChain.current_approval_chain(csa.id)[0]&.requested? }

  after_update :dispatch_approved_denied_email, if: Proc.new { |cs| cs.custom_section && cs.state.present? && cs.custom_section.is_approval_required.present? && cs.saved_change_to_state? && (cs.approved? || cs.denied?) && cs.requester_id.present? && !cs.skip_dispatch_email }
  after_destroy :dispatch_approved_denied_email, if: Proc.new { |cs| cs.custom_section && cs.state.present? && cs.custom_section.is_approval_required.present? && cs.requested? && cs.requester_id.present? && cs.user_id.present? && !cs.skip_dispatch_email }
  
  scope :is_custom_field_in_requested, -> (custom_field_id, user_id) { where(state: CustomSectionApproval.states[:requested], user_id: user_id).joins(:requested_fields).where(requested_fields: {custom_field_id: custom_field_id}).count }
  scope :get_custom_field_in_requested, -> (custom_field_id, user_id) { where(state: CustomSectionApproval.states[:requested], user_id: user_id).joins(:requested_fields).where(requested_fields: {custom_field_id: custom_field_id}).pluck('requested_fields.custom_field_value').take(1) }
  scope :get_pending_custom_section_approvals_count, -> (current_company){joins(:custom_section).where("custom_sections.company_id = ? AND (custom_sections.is_approval_required = TRUE AND custom_section_approvals.state = ?)",
        current_company.id, CustomSectionApproval.states[:requested]).count }

  def get_values_for_custom_section_approval(user, custom_section_approval)
    requested_fields = custom_section_approval.requested_fields
    old_field_values = []
    new_field_values = []

    default_values = user.get_default_fields_values_against_requested_attributes(requested_fields)
    custom_values = user.get_custom_fields_values_against_requested_attributes(requested_fields)

    old_field_values = default_values[:old_values] + custom_values[:old_values]
    new_field_values = default_values[:new_values] + custom_values[:new_values]
    return {old_field_values: old_field_values, new_field_values: new_field_values}
  end

  def create_cs_approval_chains
    custom_section = self.custom_section
    company = custom_section.company
    user = self.user
    approver_present = false

    approval_chains = self.get_approval_chains
    approval_chains.reorder(id: :asc).try(:each) do |approval_chain|
      approver = nil
      state = CsApprovalChain.states[:requested]

      case approval_chain.approval_type
      when 'person'
        approver = company.users.find_by(id: approval_chain.approval_ids)
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

      if approver&.id == self.requester_id
        state = CsApprovalChain.states[:skipped]
        approver_present = true
      end

      self.cs_approval_chains.create(approval_chain_id: approval_chain.id, state: state)
    end

    skip_requests_till_requester if approver_present
  end

  def skip_requests_till_requester
    self.skip_dispatch_email = true
    self.cs_approval_chains.where('id < ?', self.cs_approval_chains.where(state: CsApprovalChain.states[:skipped]).take.try(:id)).update_all(state: CsApprovalChain.states[:skipped])
    self.skip_dispatch_email = false
  end

  def approvers
    user_data = {}
    user_data["approver_names"] = []
    user_data["approver_ids"] = []
    user_data["approvers_emails"] = []

    if self.state.present? && self.custom_section.is_approval_required.present? && self.requester_id.present?
      approval = CsApprovalChain.current_approval_chain(self.id)[0]
      if approval&.requested?
        if approval.approval_chain.permission?
          if !approval.approval_chain.approval_ids.include? 'all'
            user_roles = self.custom_section.company.user_roles.where(id: approval.approval_chain.approval_ids)
          else
            user_roles = self.custom_section.company.user_roles.all
          end
          user_data["approver_names"].concat user_roles.collect(&:name)
          user_data["approver_ids"].concat user_roles.collect { |user_role| 
            user_role.try(:users).not_inactive_incomplete.pluck(:id) 
          }.flatten
          user_data["approvers_emails"].concat user_roles.collect { |role| 
            role.users.not_inactive_incomplete.map{ |user| 
              user.email.present? ? user.email : user.personal_email 
            } 
          }.flatten

          return user_data

        elsif approval.approval_chain.person?
          user = self.custom_section.company.users.find_by(id: approval.approval_chain.approval_ids)
          if user.present? && user.active?
            user_data["approver_names"].push user.try(:preferred_full_name)
            user_data["approver_ids"].push user.try(:id)
            user_data["approvers_emails"].push user.email.present? ? user.email : user.personal_email
          end
          return user_data

        elsif approval.approval_chain.manager?
          user = self.user
          original_user = self.custom_section.company.users.find_by(id: user.id)
          if user.present? && original_user.present? && user.active?
            manager = user.manager_level(approval.approval_chain.approval_ids[0])
            return nil if !manager.present? || manager.inactive?
            email = manager.try(:email).present? ? manager.try(:email) : manager.try(:personal_email)
            user_data["approver_names"].push manager.try(:preferred_full_name)
            user_data["approver_ids"].push manager.try(:id)
            user_data["approvers_emails"].push email

          end
          return user_data

        elsif approval.approval_chain.requestor_manager?
          requestor = self.requester
          if requestor.present? && requestor.active?
            manager = requestor.manager_level(approval.approval_chain.approval_ids[0])
            return nil if !manager.present? || manager.inactive?
            email = manager.try(:email).present? ? manager.try(:email) : manager.try(:personal_email)
            user_data["approver_names"].push manager.try(:preferred_full_name)
            user_data["approver_ids"].push manager.try(:id)
            user_data["approvers_emails"].push email

          end
          return user_data

        elsif approval.approval_chain.coworker?
          approval_id = approval.approval_chain.approval_ids[0]
          user = self.user.get_custom_coworker approval_id

          if user.present? && user.active?
            user_data["approver_names"].push user.try(:preferred_full_name)
            user_data["approver_ids"].push user.try(:id)
            user_data["approvers_emails"].push user.try(:email).present? ? user.try(:email) : user.try(:personal_email)
          end
          return user_data

        elsif approval.approval_chain.individual?
          user = self.user
          original_user = self.custom_section.company.users.find_by(id: user.id)
          if user.present? && original_user.present? && original_user.active?
            user_data["approver_names"].push user.try(:preferred_full_name)
            user_data["approver_ids"].push user.try(:id)
            user_data["approvers_emails"].push user.try(:email).present? ? user.try(:email) : user.try(:personal_email)
          end
          return user_data
        end
      end
    end
  end

  def find_next_approver
    approval = CsApprovalChain.current_approval_chain(self.id)[0]
    self.cs_approval_chain_list(false, [approval])[0] if approval&.requested?
  end

  def cs_approval_chain_list(for_email=false, approval_chains=nil)
    custom_section = self.custom_section
    return [] unless custom_section.is_approval_required

    company = custom_section.company
    user = self.user
    original_user = company.users.find_by(id: user.id)

    approver_list = []
    approver = nil
    index = 0
    denied = false
    approval_chains ||= self.cs_approval_chains.includes([:approval_chain]).order(:id)

    approval_chains.each do |cs_approval_chain|
      approval_chain = ApprovalChain.with_deleted.find_by(id: cs_approval_chain.approval_chain_id)
      next unless approval_chain.present?

      approver = nil
      user_data = {}
      user_data["approver_id"] = nil
      user_data["approver_permission_ids"] = nil
      user_data["approver_names"] = ''
      user_data["approver_type"] = ''
      user_data["approver_picture"] = ''
      user_data["approver_status"] = ''
      user_data["approver_initials"] = ''
      user_data["current_approver"] = false
      user_data["approval_date"] = ''
      user_data["index"] = index+=1

      current_chain = CsApprovalChain.current_approval_chain(self.id)[0]
      user_data["current_approver"] = true if current_chain.present? && cs_approval_chain.id == current_chain.id
      user_data["approval_date"] = cs_approval_chain.approval_date&.strftime('%b %d, %Y')

      if cs_approval_chain.approved? || cs_approval_chain.denied?
        user_data["approver_status"] = cs_approval_chain.state.to_s 
        approver = company.users.with_deleted.find_by(id: cs_approval_chain.approver_id)
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
        user_data["approver_id"] = approver.try(:id)

      else
        approver = User.current if for_email.present? && denied == false && cs_approval_chain.requested?
        user_data["approver_type"] = approver.try(:user_role).try(:name) if approver.present?

        if approver.nil?
          case approval_chain.approval_type

          when 'permission'
            if !approval_chain.approval_ids.include? 'all'
              user_roles = company.user_roles.where(id: approval_chain.approval_ids)
            else
              user_roles = company.user_roles.all
            end
            user_data["approver_names"] = user_roles.collect(&:name).map(&:inspect.to_sym).join(', ').remove('"')
            user_data["approver_permission_ids"] = user_roles.collect(&:id).map(&:inspect.to_sym).join(', ').remove('"')
            user_data["approver_type"] = 'Permission Group'
            user_data["approver_initials"] = 'P G'
          when 'person'
            approver = company.users.with_deleted.find_by(id: approval_chain.approval_ids)
            user_data["approver_type"] = approver.try(:title)
          when 'manager'
            approver = original_user.manager_level(approval_chain.approval_ids[0])
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

      user_data["approver_requested"] = true if cs_approval_chain.requested?
      
      if ((self.denied? && cs_approval_chain.denied?) || (cs_approval_chain.requested? && approver.present?)) && for_email.present? && denied == false
        user_data["approver_status"] = 'denied'
        user_data["approver_requested"] = false
        denied = true
      end

      if approval_chain.approval_type != 'permission' || (approval_chain.approval_type == 'permission' && (cs_approval_chain.approved? || (cs_approval_chain.requested? && for_email.present?)))
        user_data["approver_status"] = 'undefined' if approver.blank? || approver.inactive?
        user_data["approver_id"] = approver.try(:id)
        user_data["approver_names"] = approver.try(:preferred_full_name)
        user_data["approver_picture"] = approver.try(:picture)
        user_data["approver_initials"] = approver.try(:initials)
        user_data["approver_type"] = approver.try(:user_role).try(:name) if cs_approval_chain.approved? && approval_chain.approval_type == 'permission'
      end

      if for_email.present?
        user_data = map_approver_status(user_data)
      end
      approver_list.push(user_data)
    end

    approver_list
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

  def dispatch_request_change_email
    custom_section = self.try(:custom_section)
    user_approvers = approvers

    if user_approvers.nil?
      approve_or_request
    else
      effective_date = self.effective_date.strftime('%b %d, %Y') rescue nil
      expiry_time = (self.created_at + custom_section.approval_expiry_time.days).strftime('%b %d, %Y') rescue nil
      if user_approvers.present? && user_approvers['approver_ids'].present?
        user_approvers['approver_ids'].try(:each) do |approver_id|
          UserMailer.cs_approval_request_change_email_for_approvers(custom_section.try(:company_id), self.try(:requester_id), approver_id, self.user_id, section_name_mapper(custom_section.try(:section)), effective_date, expiry_time).deliver_later!
        end
      else
        approve_or_request
      end
    end

  end

  def approve_or_request
    chain = CsApprovalChain.current_approval_chain(self.id)[0]
    chain&.update(state: CsApprovalChain.states[:skipped])
    next_chain = CsApprovalChain.current_approval_chain(self.id)[0]
    if next_chain.present?
      dispatch_request_change_email
    else
      auto_approve_request
      dispatch_approved_denied_email
    end
  end

  def auto_approve_request
    log = logging.create(self.custom_section.company, 'Auto Approving Request', {custom_section_approval: self, request: "#{custom_section.try(:name)} - AutoApprovingRequest(#{user.id}:#{user.full_name})"}, 'CustomSections')
    update_column(:state, CustomSectionApproval.states[:approved])
    CustomSections::AssignRequestedFieldValue.new.assign_values_to_user(self)
  end

  def dispatch_approved_denied_email
    created_at = self.created_at.strftime('%b %d, %Y') rescue nil
    UserMailer.cs_section_approval_request_approved_denied_email_notification(self.try(:custom_section).try(:company_id), created_at, self.user_id, self.requester_id, self.state, self.cs_approval_chain_list(true, self.cs_approval_chains.with_deleted.order(:id)), section_name_mapper(self.try(:custom_section).section)).deliver_later! if self.requested? || self.approved? || self.denied?
  end

  def section_name_mapper(section)
    case section
    when 'profile'
      'Profile Information'
    when 'personal_info'
      'Personal Information'
    when 'private_info'
      'Private Information'
    when 'additional_fields'
      'Additional Information'
    end
  end

  def self.destroy_requested_fields(field_id, is_default, section_id, company, user_id = nil)
    key = is_default == 'true' ? 'preference_field_id' : 'custom_field_id'
    requested_fields_ids = nil
    csa_constraints = {state: 'requested'}
    csa_constraints.merge!(custom_section_id: section_id) if section_id.present?
    csa_constraints.merge!(user_id: user_id) if user_id.present?
    requested_fields_ids = company.custom_sections.joins(custom_section_approvals: :requested_fields).where(custom_section_approvals: csa_constraints).where(requested_fields: {"#{key}": field_id}).pluck('requested_fields.id')
    return unless requested_fields_ids.present?
    CustomSectionApproval.delete_selected_requested_fields_or_cs_approval(requested_fields_ids)
  end

  def self.delete_selected_requested_fields_or_cs_approval(requested_fields_ids)
    requested_fields_ids.try(:each) do |rf_id|
      rf = RequestedField.find_by(id: rf_id)
      if rf.present?
        rf.custom_section_approval.requested_fields.length == 1 ? rf.custom_section_approval.destroy : rf.destroy
      end
    end
  end

  def self.get_custom_section_approval_values(user_id, cs_approval_id, current_company)
    user = current_company.users.find_by(id: user_id)
    cs_approval = user.custom_section_approvals.find_by(id: cs_approval_id)
    cs_approval.present? ? cs_approval.get_values_for_custom_section_approval(user, cs_approval) : []
  end

  def logging
    @logging ||= LoggingService::GeneralLogging.new
  end

  def access_permission
    custom_sections = PermissionService.new.fetch_accessable_custom_field_sections(self.custom_section.company, User.current, self.user.id)
    custom_sections.include?(CustomField.sections[self.custom_section.section])
  end

  def get_approval_chains
    self.approval_chains.present? ? self.approval_chains : self.custom_section.approval_chains
  end
end


