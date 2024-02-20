class PaperworkPacket < ApplicationRecord
  acts_as_paranoid
  belongs_to :company
  belongs_to :user
  belongs_to :updated_by, class_name: 'User', foreign_key: :updated_by_id

  has_many :paperwork_packet_connections, dependent: :destroy
  has_many :paperwork_requests
  has_many :user_document_connections, class_name: 'UserDocumentConnection', foreign_key: :packet_id

  validates :name, :description, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE)

  enum packet_type: { bulk: 0, individual: 1 }

  accepts_nested_attributes_for :paperwork_packet_connections

  after_destroy :remove_pending_paperwork_requests, if: Proc.new {|pp| pp.paperwork_requests.present? && pp.paperwork_requests.where(state: 'preparing').count > 0 }
  after_destroy :remove_pending_upload_requests, if: Proc.new {|pp| pp.user_document_connections.present? && pp.user_document_connections.where(state: 'request').count > 0 }

  def documents
    documents = []
    self.paperwork_packet_connections.each do |connection|
      if connection.connectable_type == 'PaperworkTemplate'
        paperwork_template =  connection.connectable
        template_id = paperwork_template.id
        document_id = paperwork_template.document.id
        title = paperwork_template.document.title
        co_signer = ""
        if paperwork_template.is_manager_representative
          co_signer = 'Manager'
          co_signer_id = nil 
          preferred_name = nil
          last_name = nil
          first_name= nil
          co_signer_pict = nil
          co_signer_email = nil
        elsif paperwork_template.representative_id.present?
          representative = paperwork_template.representative
          co_signer = representative.try(:display_name)
          co_signer_id = representative.id
          co_signer_pict = representative.try(:picture)
          preferred_name = representative.try(:preferred_name)
          last_name = representative.try(:last_name)
          first_name= representative.try(:first_name)
          co_signer_email = representative.try(:personal_email) || representative.try(:email)
        end
        documents.push({paperwork_packet_connection_id: connection.id, title: title, type: connection.connectable_type, co_signer_id: co_signer_id, co_signer: co_signer, co_signer_pict: co_signer_pict, preferred_name: preferred_name, first_name: first_name, last_name: last_name, co_signer_email: co_signer_email, template_id: template_id, document_id: document_id})
      elsif connection.connectable_type == 'DocumentUploadRequest'
        document_upload_request = connection.connectable
        title =  document_upload_request.document_connection_relation.title
        documents.push({paperwork_packet_connection_id: connection.id, title: title, type: connection.connectable_type, co_signer: nil, co_signer_pict: nil, global: document_upload_request.global, special_user_id: document_upload_request.special_user_id, document_connection_relation_id: document_upload_request.document_connection_relation_id})
      end
    end
    documents
  end

  def user_assigned_count
    user_document_connections_count = []
    paperwork_requests_count = self.paperwork_requests.distinct(:user_id).pluck(:user_id)
    user_document_connections_count = paperwork_requests_count.length > 0 ? self.user_document_connections.where.not(user_id: paperwork_requests_count).distinct(:user_id).pluck(:user_id) : self.user_document_connections.distinct(:user_id).pluck(:user_id)
    (user_document_connections_count | paperwork_requests_count).length
  end

  def self.exclude_duplicate_documents_in_packet(paperwork_packet,packet_params) 
    return if packet_params.blank?
    updated_docs = []
    existing_docs = paperwork_packet.paperwork_packet_connections
    packet_params.each do |params_doc|
      next if existing_docs.count { |ed| ed.connectable_id == params_doc[:connectable_id] && ed.connectable_type == params_doc[:connectable_type] }.positive? && updated_docs.include?(params_doc)
      updated_docs.push(params_doc)
    end
    updated_docs
  end

  private

  def remove_pending_paperwork_requests
    self.paperwork_requests.where(state: 'preparing').delete_all
  end

  def remove_pending_upload_requests
    self.user_document_connections.where(state: 'request').delete_all
  end
end

