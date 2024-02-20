class DocumentUploadRequest < ApplicationRecord
  include UserStatisticManagement
  
  has_paper_trail
  acts_as_paranoid
  belongs_to :company
  belongs_to :special_user, class_name: 'User'
  belongs_to :user
  belongs_to :document_connection_relation
  belongs_to :updated_by, class_name: 'User'

  has_many :paperwork_packet_connections, dependent: :destroy, :as => :connectable

  accepts_nested_attributes_for :document_connection_relation

  after_destroy :remove_relation, if: Proc.new { |document_upload_request| document_upload_request.document_connection_relation.present? }
  after_destroy :remove_user_document_connection, if: Proc.new { |document_upload_request| document_upload_request.document_connection_relation.present? && document_upload_request.document_connection_relation.user_document_connections.present? && document_upload_request.document_connection_relation.user_document_connections.where.not(state: 'completed').count > 0 }
  
  after_update :remove_packet_connection, if: :precess_type_changed?

  def remove_relation
    self.document_connection_relation.delete if self.document_connection_relation
  end

  def remove_user_document_connection
    self.document_connection_relation.user_document_connections.where.not(state: 'completed').delete_all if self.document_connection_relation.user_document_connections
  end

  def get_title
    self.document_connection_relation.present? ? self.document_connection_relation.title : ""
  end

  def get_description
    self.document_connection_relation.present? ? self.document_connection_relation.description : ""
  end

  def duplicate_request
    document = self.document_connection_relation
    pattern = "#{self.document_connection_relation.title.to_s[0,self.document_connection_relation.title.length]}"
    document_upload_requests_data = self.company.document_upload_requests.includes(:document_connection_relation)
    count = 0
    document_upload_requests_data.each do |dur|
      if (pattern.in? dur.document_connection_relation.title)
        count = count + 1 
      end
    end
    new_document = document.dup
    new_document.title = "Copy of #{document.title} (#{count})"
    new_document.save!

    new_document_upload_request = self.dup
    new_document_upload_request.updated_by_id = User.current.id
    new_document_upload_request.document_connection_relation_id = new_document.id
    new_document_upload_request.save!

    return new_document_upload_request
  end

  private

  def precess_type_changed?
    self.saved_change_to_meta? && self.saved_changes['meta'][0]["type"] != self.saved_changes['meta'][1]["type"]
  end

  def remove_packet_connection
    self.paperwork_packet_connections.destroy_all
  end
end
