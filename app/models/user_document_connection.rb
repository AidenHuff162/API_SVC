class UserDocumentConnection < ApplicationRecord
  include UserStatisticManagement, SendDocumentToThirdParty
  
  acts_as_paranoid
  has_paper_trail
  belongs_to :user, counter_cache: true
  counter_culture :user, column_name: proc {|model| (model.document_connection_relation_id && model.request?) ? 'incomplete_upload_request_count' : nil },
                         column_names: {['user_document_connections.document_connection_relation_id IS NOT NULL AND user_document_connections.state = ?', 'request'] => 'incomplete_upload_request_count'}
  belongs_to :document_connection_relation
  after_save :fix_user_documents_count
  after_create :enable_activity_notification, if: Proc.new {|user_document_connection| user_document_connection.user.present?}
  after_create :change_state_draft_to_request, unless: Proc.new {|user_document_connection| user_document_connection.smart_assignment.present?}
  after_create :update_user_task_dates, if: :check_user_start_and_due_date?
  after_update :send_document_to_third_parties , if: :completed?
  after_destroy :remove_relation, unless: Proc.new {|user_document_connection| user_document_connection.document_connection_relation.present? && (user_document_connection.document_connection_relation.document_upload_request.present? || (user_document_connection.document_connection_relation.present? && user_document_connection.document_connection_relation.user_document_connections.present?)) }
  belongs_to :created_by, class_name: 'User', foreign_key: :created_by_id
  belongs_to :paperwork_packet, class_name: 'PaperworkPacket', foreign_key: :packet_id

  validate :user_presence
  attr_accessor :smart_assignment

  scope :draft_connections, -> { where("state = 'draft'") }
  scope :non_draft_connections, -> { where.not(state: :draft) }
  scope :get_pending_sibling_requests, -> (document_token){ where('document_token = ? AND state IN (?)', document_token, 'draft') }
  scope :get_assigned_sibling_requests, -> (document_token){ where('document_token = ?', document_token) }
  scope :exclude_offboarded_user_documents, -> (company_id) { joins(:user).where('users.company_id = ? AND users.state != ? AND users.current_stage != ?', company_id, 'inactive', User.current_stages[:departed]) }
  scope :get_pending_documents, -> { joins(:document_connection_relation).where(state: :request) }
  scope :user_doc_without_due_date, -> { joins(:document_connection_relation).where("user_document_connections.state = 'request' and due_date is null").joins(:user).where("users.start_date < ?", 2.months.ago).pluck(:user_id) }
  scope :user_doc_with_due_date, -> { joins(:document_connection_relation).where("state = 'request' and due_date is not null and due_date < ?",Date.today ).pluck(:user_id) }

  with_options as: :entity do |record|
    record.has_many :attached_files, class_name: 'UploadedFile::DocumentUploadRequestFile'
  end

  def remove_relation
    self.document_connection_relation.delete if self.document_connection_relation
  end

  def completed?
    self.state == 'completed'
  end

  def check_user_start_and_due_date?
    self.due_date.blank? && self.user&.start_date&.present?
  end

  def request?
    self.state == 'request'
  end

  def draft?
    self.state == 'draft'
  end

  state_machine :state, initial: :draft do
    event :request do
      transition draft: :request
    end
    event :complete do
      transition request: :completed
    end
  end

  state_machine :email_status, initial: :email_not_sent do
    event :email_completely_send do
      transition :email_not_sent => :email_completely_sent
    end

    after_transition on: :email_completely_send, do: :send_document_email
  end

  def enable_activity_notification
    self.user.enable_document_notification
  end
  
  # To handle the existing data on updating the document upload request from tool page
  def self.overdue_upload_requests_count(company)
    UserDocumentConnection.non_draft_connections.exclude_offboarded_user_documents(company.id).get_pending_documents.where("user_document_connections.due_date < ?", company.time.to_date).count
  end

  # To handle the existing data on updating the document upload request from tool page
  def self.open_upload_requests_count(company)
    UserDocumentConnection.non_draft_connections.exclude_offboarded_user_documents(company.id).get_pending_documents.where("user_document_connections.due_date is NULL OR user_document_connections.due_date >= ?", company.time.to_date).count
  end

  def change_state_draft_to_request
    self.request
  end

  def update_user_task_dates
    self.update_column(:due_date, self.user.start_date + 2.months)
  end

  def self.pending_hire_draft_user_document_connections(user)
    user&.user_document_connections&.draft_connections.select(:id, :document_connection_relation_id, :packet_id)
  end

  def fix_user_documents_count
    return unless saved_change_to_state?

    UserDocumentConnection.counter_culture_fix_counts only: :user, where: { users: { id: user_id } }, column_name: :incomplete_upload_request_count
  end

  def send_document_email
    SendDocumentsAssignmentEmailJob.perform_async(self.id, 'user_document_connection')
  end

  def user_presence
    errors.add(:base, "User(#{self.user_id}) does not exist!") unless self&.user
  end

end
