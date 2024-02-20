class PaperworkTemplate < ApplicationRecord
  include LoggingManagement
  acts_as_paranoid
  has_paper_trail
  belongs_to :document
  belongs_to :company
  belongs_to :user

  has_many :paperwork_packet_connections, dependent: :destroy, :as => :connectable
  belongs_to :representative, class_name: "User"
  belongs_to :updated_by, class_name: 'User'

  attr_accessor :hellosign_template_edit_url, :skip_callback, :new_template_id

  after_validation :create_hellosign_template, on: :create, if: Proc.new { |pt| pt.skip_callback.nil? }

  after_destroy :remove_hellosign_template
  after_destroy :remove_document, if: Proc.new {|paperwork_template| paperwork_template.document.present? }

  after_validation :update_hellosign_template, on: :update, if: Proc.new { |pt| pt.document_id_in_database.present? && pt.document_id_in_database != pt.document_id }

  after_update :update_pending_documents_cosigner, if: Proc.new { |pt| pt.saved_change_to_representative_id? }

  scope :get_saved_paperwork_templates, -> (paperwork_template_id) {where(id: paperwork_template_id, state: 'saved')}

  SKIP_ACTION = 1

  #:nocov:
  def remove_document
    if self.document.paperwork_requests.present?
      self.document.paperwork_requests.where(state: 'preparing').delete_all
      self.document.delete if self.document.paperwork_requests.where.not(state: 'preparing').count == 0
    else
      self.document.delete
    end
  end

  #:nocov:
  state_machine :state, initial: :draft do
    event :finalize do
      transition :draft => :saved
    end
  end

  def remove_hellosign_template
    begin
      HelloSign.delete_template :template_id => self.hellosign_template_id
    rescue HelloSign::Error::NotFound => e
      create_general_logging(self.company, "Remove Hellosign Template", {api_request: "Remove Hellosign Template", integration_name: "Hellosign", error: e.message, paperwork_template: self.id})
    rescue Exception => e
      #:nocov:
      create_general_logging(self.company, "Remove Hellosign Template", {api_request: "Remove Hellosign Template", integration_name: "Hellosign", error: e.message})
      self.errors.add(:id, I18n.t('errors.try_agian'))
      #:nocov:
    end
  end

  def hellosign_file_param
    if !Rails.env.development? && !Rails.env.test?
      return :file_urls
    else
      return :files
    end
  end

  def is_cosigned?
    return self.representative_id.present? || self.is_manager_representative.present?
  end

  def fields_data
    '{"name":"Full Name" , "type":"text"},
     {"name":"First Name" , "type":"text"},
     {"name":"Last Name" , "type":"text"},
     {"name":"Preferred/ First Name" , "type":"text"},
     {"name":"Job Title" , "type":"text"},
     {"name":"Personal Email" , "type":"text"},
     {"name":"Company Email" , "type":"text"},
     {"name":"Location" , "type":"text"},
     {"name":"Department" , "type":"text"},
     {"name":"Old Start Date" , "type":"text"},
     {"name":"Current Start Date" , "type":"text"},
     {"name":"Last Day Worked" , "type":"text"},
     {"name":"Start Date" , "type":"text"},
     {"name":"Buddy First Name" , "type":"text"},
     {"name":"Buddy Full Name" , "type":"text"},
     {"name":"Buddy Title" , "type":"text"},
     {"name":"Buddy Email" , "type":"text"},
     {"name":"Buddy Department" , "type":"text"},
     {"name":"Buddy Location" , "type":"text"},
     {"name":"Manager First Name" , "type":"text"},
     {"name":"Manager Full Name" , "type":"text"},
     {"name":"Manager Title" , "type":"text"},
     {"name":"Manager Email" , "type":"text"},
     {"name":"Manager Department" , "type":"text"},
     {"name":"Manager Location" , "type":"text"},
     {"name":"Termination type" , "type":"text"},
     {"name":"Termination Date" , "type":"text"},
     {"name":"Status" , "type":"text"},
     {"name":"Access Permission" , "type":"text"},
     {"name":"Eligible for Rehire" , "type":"text"},
     {"name":"About" , "type":"text"},
     {"name":"Facebook" , "type":"text"},
     {"name":"LinkedIn" , "type":"text"},
     {"name":"Twitter" , "type":"text"},
     {"name":"Github" , "type":"text"},'
  end

  def get_signer_roles
    signer_roles = [{ name: 'employee', order: 0 }]
    signer_roles << { name: 'representative', order: 1 } if representative && !is_manager_representative
    signer_roles << { name: 'coworker', order: 1 } if is_manager_representative
    signer_roles
  end

  def create_hellosign_template
    fields = fields_data
    company.custom_fields.where.not(name: 'Effective Date').pluck(:name).each do |field_name|
      fields += '{"name":"'+field_name+'" , "type":"text"},'
    end
    fields = "["+fields.chomp(",")+"]"
    fields = JSON.parse(fields).uniq.to_json
    begin
      signer_roles = get_signer_roles
      request = HelloSign.create_embedded_template_draft(
        test_mode: self.company.get_hellosign_test_mode,
        client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
        hellosign_file_param => [self.document&.attached_file&.url_for_hellosign],
        title: self.document.title,
        message: self.document.description,
        signer_roles: signer_roles,
        merge_fields: fields
      )
      #:nocov:
      if request.present?
        self.hellosign_template_id = request.data["template_id"]
        self.hellosign_template_edit_url = request.data["edit_url"]
      end
      #:nocov:
    rescue HelloSign::Error::Conflict => e
      #:nocov:
      self.errors.add(:template_id, I18n.t('errors.identical_request'))
      #:nocov:
    rescue Exception => e
      create_general_logging(self.company, "Create Hellosign Template", {api_request: "Create Hellosign Template", integration_name: "Hellosign", error: e.message})
      self.errors.add(:template_id, I18n.t('errors.try_agian'))
    end
  end

  def duplicate_template
    document = self.document
    company  = document.company
    new_document = document.dup
    pattern = "%#{new_document.title.to_s[0,new_document.title.length-1]}%"
    duplicate_name = new_document.title.insert(0, 'Copy of ')
    duplicate_name = duplicate_name + " (#{company.documents.where("title LIKE ?",pattern).count})"
    new_document.title = duplicate_name
    # new_document.title = "Copy of #{document.title}"
    new_document.save!
    new_document.duplicate_attachment_file(document.attached_file) if document.attached_file.present?

    new_paperwork_template = self.dup
    new_paperwork_template.document_id = new_document.id
    new_paperwork_template.state = 'draft'
    new_paperwork_template.updated_by_id = User.current&.id
    new_paperwork_template.save!

    return new_paperwork_template
  end
  #:nocov:
  def update_hellosign_template
    document = company.documents.find_by(id: document_id_in_database)
    document.delete unless document&.paperwork_requests&.any?
    remove_hellosign_template
    self.hellosign_template_id = nil
    create_hellosign_template
  end
  #:nocov:

  def update_pending_documents_cosigner
    pending_paperwork_requests = self.document.paperwork_requests.where(co_signer_id: self.representative_id_before_last_save).where.not(state: ['all_signed', 'failed', 'draft'])
    pending_paperwork_requests.try(:each) do |request|
      HellosignCall.update_signature_request_cosigner(request.id, company_id, user_id)
    end
  end

  def self.get_representative_details(object, is_picture_required = false)
    representative_id = object['representative_id']
    if (
      object['paperwork_request_co_signer_id'] &&
      object['hellosign_signature_request_id'] &&
      object['paperwork_request_co_signer_id'] != PaperworkRequest.find_by(hellosign_signature_request_id: object['hellosign_signature_request_id'])&.user&.manager_id
    )
      representative_id = object['paperwork_request_co_signer_id']
    end
    return nil if !representative_id
    representative = User.find_by(id: representative_id)
    is_picture_required ? representative&.picture : representative
  end
end
