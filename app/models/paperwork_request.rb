class PaperworkRequest < ApplicationRecord
  include TokenReplacementHashGenerator, UserStatisticManagement, LoggingManagement, HistoryHandler, SendDocumentToThirdParty
  has_paper_trail
  acts_as_paranoid
  belongs_to :user
  counter_culture :user, column_name: proc {|model| (model.preparing? || model.assigned? || model.failed?) ? 'incomplete_paperwork_count' : nil },
                         column_names: {['paperwork_requests.state IN (?)', ['preparing','assigned', 'failed']] => 'incomplete_paperwork_count'}
  belongs_to :document
  belongs_to :requester, class_name: 'User', foreign_key: 'requester_id'
  belongs_to :co_signer, class_name: 'User', foreign_key: 'co_signer_id'
  counter_culture :co_signer, column_name: proc {|model| model.co_signer_id && model.signed? ? 'co_signer_paperwork_count' : nil },
                              column_names: {['paperwork_requests.co_signer_id IS NOT NULL AND paperwork_requests.state = ?', 'signed'] => 'co_signer_paperwork_count'}

  mount_uploader :signed_document, FileUploader
  mount_uploader :unsigned_document, FileUploader
  belongs_to :paperwork_packet
  belongs_to :paperwork_packet_deleted, -> { with_deleted } , :class_name => "PaperworkPacket", :foreign_key => 'paperwork_packet_id'
  belongs_to :document_with_deleted, -> { with_deleted } , :class_name => "Document", :foreign_key => 'document_id'

  attr_accessor :hellosign_claim_url, :hellosign_signature_url, :send_completion_email, :smart_assignment, :state_assignment, :skip_callback

  after_validation :create_signature_request, on: :create
  after_destroy :remove_document, unless: -> { document&.paperwork_template }

  after_create :change_draft_state_to_preparing
  after_update :send_document_to_third_parties, if: :should_send_to_third_party?
  #ROI email management
  after_commit :set_signature_completion_date, on: [:create, :update]
  after_commit :manage_post_sign_things, if: Proc.new { |pr| pr.skip_callback.blank? && pr.saved_change_to_state? && (pr.signed? || pr.all_signed?) }
 
  enum paperwork_packet_type: { bulk: 0, individual: 1 }
  enum co_signer_type: { manager: 0, team_member: 1 }

  HELLOSIGN_REQUEST_DOWNLOADABLE_EVENT = 'signature_request_downloadable'
  HELLOSIGN_REQUEST_SIGNED_EVENT = 'signature_request_signed'
  HELLOSIGN_REQUEST_ALL_SIGNED_EVENT = 'signature_request_all_signed'
  HELLOSIGN_WEBHOOK_EVENTS = [HELLOSIGN_REQUEST_DOWNLOADABLE_EVENT, HELLOSIGN_REQUEST_SIGNED_EVENT, HELLOSIGN_REQUEST_ALL_SIGNED_EVENT]

  scope :missing_signed_documents, -> { where("((state = 'emp_submitted') or (state = 'cosigner_submitted' and co_signer_id is not null)) and signed_document is null and updated_at <= ?", 10.minutes.ago) }
  scope :documents_needs_fix, -> { where("hellosign_modal_opened_at >= ?", 10.minutes.ago) }
  scope :draft_requests, -> { where("state = 'draft'") }
  scope :non_draft_requests, -> { where.not(state: :draft) }
  scope :span_based_signed_documents, -> (company_id, begin_date, end_date){ joins(:user).where('users.company_id = ? AND ((paperwork_requests.co_signer_id IS NOT NULL AND paperwork_requests.state = ?) OR
    (paperwork_requests.co_signer_id IS NULL AND paperwork_requests.state = ?)) AND paperwork_requests.signature_completion_date IS NOT NULL AND paperwork_requests.signature_completion_date >= ? AND
    paperwork_requests.signature_completion_date <= ?', company_id, 'all_signed', 'signed', begin_date, end_date) }
  scope :get_pending_sibling_requests, -> (document_token){ where('document_token = ? AND state IN (?)', document_token, ['draft', 'preparing']) }
  scope :get_assigned_sibling_requests, -> (document_token){ where('document_token = ? AND state NOT IN (?)', document_token, ['draft', 'preparing']) }
  scope :exclude_offboarded_user_documents, -> { joins(:user).where.not(users: { state: :inactive, current_stage: User.current_stages[:departed] }) }
  scope :get_pending_documents, -> (company_id) { joins(:document).where("documents.company_id = ? AND (paperwork_requests.state = 'assigned' OR paperwork_requests.co_signer_id IS NOT NULL AND paperwork_requests.state != 'all_signed')", company_id) }
  scope :documents_needs_daily_fix, -> { where('hellosign_modal_opened_at >= ? AND state IN (?)', 24.hours.ago, ['assigned', 'emp_submitted', 'signed', 'cosigner_submitted', 'all_signed']) }
  scope :user_without_due_date, -> { joins(:user).where("users.current_stage != ? AND users.state = 'active' AND paperwork_requests.state = 'assigned' AND due_date IS NULL AND users.start_date < ?", User.current_stages[:departed], 2.months.ago).pluck(:user_id) }
  scope :cosigner_without_due_date , -> { joins(:user).where("users.current_stage != ? AND users.state = 'active' AND paperwork_requests.state = 'signed' AND co_signer_id IS NOT NULL AND due_date IS NULL AND users.start_date < ?", User.current_stages[:departed], 2.months.ago ).pluck(:co_signer_id) }
  scope :user_with_due_date, -> { joins(:user).where("users.current_stage != ? AND users.state = 'active' AND paperwork_requests.state = 'assigned' AND due_date IS NOT NULL AND due_date < ?", User.current_stages[:departed], Date.today).pluck(:user_id) }
  scope :cosigner_with_due_date, -> { joins(:user).where("users.current_stage != ? AND users.state = 'active' AND paperwork_requests.state = 'signed' AND co_signer_id IS NOT NULL AND due_date IS NOT NULL AND due_date < ?", User.current_stages[:departed], Date.today).pluck(:co_signer_id) }


  def remove_document
    self.document.delete if self.document && self.document.paperwork_requests.count <= 1
  end

  state_machine :state, initial: :draft do
    event :prepare do
      transition :draft => :preparing
    end

    event :assign do
      transition :draft => :assigned
      transition :preparing => :assigned
      transition :emp_submitted => :assigned
    end

    event :emp_submit do
      transition :assigned => :emp_submitted
    end

    event :sign do
      transition :emp_submitted => :signed
      transition :cosigner_submitted => :signed
    end

    event :cosigner_submit do
      transition :signed => :cosigner_submitted
    end

    event :all_signed do
      transition :cosigner_submitted => :all_signed
    end

    event :decline do
      transition :preparing => :failed
    end

    after_transition on: :assign, do: :enable_activity_notification
    after_transition on: [:emp_submit, :cosigner_submit], do: :update_hellosign_modal_opened_at
  end

  state_machine :email_status, initial: :email_not_sent do
    event :email_partially_send do
      transition :email_not_sent => :email_partially_sent
    end

    event :email_completely_send do
      transition :email_not_sent => :email_completely_sent
      transition :email_partially_sent => :email_completely_sent
    end
    
    after_transition on: :email_partially_send, do: :send_document_email
    after_transition on: :email_completely_send, do: :send_document_email
  end

  def set_signature_completion_date
    signature_completion_date = nil
    if (is_cosigned_document.blank? && self.signed?) || (is_cosigned_document.present? && self.all_signed?) || (self.co_signer_id.present? && self.all_signed?)
      signature_completion_date = Time.now.in_time_zone(self&.user&.company&.time_zone).to_date
    end
    self.update_column(:signature_completion_date, signature_completion_date)
  end

  def send_document_to_bamboo
    if self.user.company.integration_types.include?("bamboo_hr") && self.user.bamboo_id.present? && self.user.active? && ((!self.co_signer_id? && self.signed?) || (self.co_signer_id? && self.all_signed?))
      ::HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.perform_later(self, self.user)
    end
  end

  %w(signed_document unsigned_document).each do |name|
    define_method("get_#{name}_url") do
      sub_title = ''
      if name == 'signed_document'
        sub_title = self&.sign_date.present? ? self&.sign_date&.strftime("%m-%d-%Y").to_s : Date.today.strftime("%m-%d-%Y").to_s
      else
        sub_title = 'Not Signed'
      end
      if !self.paperwork_packet_id? || self.individual?
        filename = "#{self.user.full_name} - #{self.document_with_deleted.title} (#{sub_title}).pdf"
      else
        filename = "#{self.user.full_name} - #{self.paperwork_packet_deleted.name} (#{sub_title}).pdf"
      end
      self.instance_eval("#{name}").download_url(filename)
    end
  end

  def enable_activity_notification
    self.user.enable_document_notification
  end

  def get_hellosign_signature_id(email)
    # If the hellosign_signature_request_id invalid rescue exception
    begin
      request = HelloSign.get_signature_request(signature_request_id: self.hellosign_signature_request_id)
      request.data["signatures"].each do |signature|
        return signature.data["signature_id"] if signature.data["signer_email_address"] == email
      end
    rescue Exception => e
      create_general_logging(self.try(:user).try(:company), 'Get Hellosign Signature Id', {api_request: "Get Signature Request", integration_name: "Hellosign", result: {error: e.message}})
      logger.info "Invalid signature request id #{e}"
    end
    return nil
  end

  def download_half_signed_document
    begin
      response = HelloSign.signature_request_files :signature_request_id => self.hellosign_signature_request_id
      tempfile = Tempfile.new(['doc', '.pdf'])
      tempfile.binmode
      tempfile.write response
      tempfile.rewind
      tempfile.close
       self.update_column :unsigned_document, nil
      self.unsigned_document = File.open tempfile.path
      self.save

      download_url = self.unsigned_document.download_url(self.document.title)
      firebase = Firebase::Client.new("#{ENV['FIREBASE_DATABASE_URL']}", ENV['FIREBASE_ADMIN_JSON'])
      response = firebase.set("paperwork_packet/" + self.hellosign_signature_request_id, download_url)
    rescue Net::ReadTimeout => exception
      retry

    rescue HelloSign::Error::Conflict => e
      errors.add(:signature_request_id, I18n.t('errors.identical_request'))

    rescue HelloSign::Error::UnknownError => e
      errors.add(:signature_request_id, I18n.t('errors.timeout_error'))

    rescue Exception => e
      create_general_logging(self.try(:user).try(:company), 'Download Half Signed Document', {api_request: "Firebase Paperwork Packet Request", integration_name: "Hellosign", result: {error: e.message, download_url: download_url, hellosign_signature_request_id: self.hellosign_signature_request_id}})
      errors.add(:signature_request_id, I18n.t('errors.try_agian'))
    end
  end

  def update_hellosign_signature_email(old_email, new_email)
    begin
      signature_id = self.get_hellosign_signature_id old_email
      HelloSign.update_signature_request({signature_request_id: self.hellosign_signature_request_id,
                                          signature_id: signature_id ,email_address: new_email}
                                        ) if signature_id.present?
    rescue Exception => e
      create_general_logging(self.try(:user).try(:company), 'Update Hellosign Signature Email', {api_request: "Update Signature Request", integration_name: "Hellosign", result: {error: e.message, old_email: old_email, new_email: new_email, paperwork_request_id: self.id }})
      puts e
      puts '-----------------------------------------------------'
      puts "----------UpdateSignatureRequestJob Exception with emails old email is = #{old_email} and new email is = #{new_email} with paperwork_request id = #{self.id} -------------"
      puts '-----------------------------------------------------'
    end
  end

  def get_signature_url(email)
    begin
      user = self.user.company.users.where('email = :email OR personal_email = :email', email: email).first
      if user && self.hellosign_signature_request_id.present?
        request = HelloSign.get_signature_request signature_request_id: self.hellosign_signature_request_id
        request.data["signatures"].each do |signature|
          if (user.email && signature.data["signer_email_address"] == user.email) || (user.personal_email && signature.data["signer_email_address"] == user.personal_email)
            self.hellosign_signature_id = signature.data["signature_id"]
          end
        end
        if self.hellosign_signature_id
          request = HelloSign.get_embedded_sign_url signature_id: self.hellosign_signature_id
          self.hellosign_signature_url = request.data["sign_url"]
          return self.hellosign_signature_url
        end
      end
      return false
    rescue Exception => e
      create_general_logging(self.try(:user).try(:company), 'Get Signature Url', {api_request: "Get Signature Request/Get Embedded Sign Url", integration_name: "Hellosign", result: { error: e.message, paperwork_request_id: self.id }})

      self.errors.add(:signature_request_id, I18n.t('errors.request_not_found'))
      SlackNotificationJob.perform_later(user.company_id, {
            username: user.full_name,
            text: I18n.t('errors.request_not_found')
          })
    end
  end

  def create_signature_request
    return true if self.smart_assignment
    if self.document
      paperwork_template = self.document.paperwork_template
    end
    if paperwork_template && paperwork_template.state == 'saved'
      #create unclaimed draft need to use claim url then this template become available
      create_signature_request_with_template paperwork_template
    else
      create_signature_draft
    end
  end

  def merge_field_value(name)
    @merge_field_values ||= getTokensHash(self.user)
    @merge_field_values[name]
  end


  def create_signature_request_with_template(paperwork_template)
    begin
      if !self.paperwork_packet_id
        request = HelloSign.get_template template_id: paperwork_template.hellosign_template_id
        merge_fields = request.data["custom_fields"]
        custom_fields = {}
        merge_fields.each do |merge_field|
          custom_fields[merge_field.data["name"]] = merge_field_value(merge_field.data["name"])
        end
        signer_roles = get_signer_roles()
        request = HelloSign.create_embedded_unclaimed_draft_with_template(
            test_mode: self.user.company.get_hellosign_test_mode,
            client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
            template_id: paperwork_template.hellosign_template_id,
            subject: self.document.title,
            message: self.document.description,
            requester_email_address: self.requester.email || self.requester.personal_email,
            is_for_embedded_signing: 1,
            signers: signer_roles,
            custom_fields: custom_fields
        )
        self.hellosign_signature_request_id = request.data["signature_request_id"]
        self.hellosign_claim_url = request.data["claim_url"]
        HellosignCall.create_embedded_unclaimed_draft_with_template(self.user.company_id, self.requester_id, self.user.id)
      else
        if self.paperwork_packet.packet_type == PaperworkPacket.packet_types.key(PaperworkPacket.packet_types[:bulk])  && !is_cosigned_document() && self.user.company
          paperwork_templates = self.user.company.paperwork_templates.where(id: self.template_ids, state: 'saved')

          custom_fields = {}
          template_ids = []
          paperwork_templates.each do |paperwork_template|
            template_ids.push paperwork_template.hellosign_template_id
            request = HelloSign.get_template template_id: paperwork_template.hellosign_template_id
            merge_fields = request.data["custom_fields"]
            merge_fields.each do |merge_field|
              custom_fields[merge_field.data["name"]] = merge_field_value(merge_field.data["name"])
            end
          end

          signer_roles = get_signer_roles()

          if template_ids.present?

            request = HelloSign.create_embedded_unclaimed_draft_with_template(
                test_mode: self.user.company.get_hellosign_test_mode,
                client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
                template_ids: template_ids,
                subject: self.document.title,
                message: self.document.description,
                requester_email_address: self.requester.email || self.requester.personal_email,
                is_for_embedded_signing: 1,
                signers: signer_roles,
                custom_fields: custom_fields
            )
            self.paperwork_packet_type = PaperworkRequest.paperwork_packet_types[:bulk]
            self.hellosign_signature_request_id = request.data["signature_request_id"]
            self.hellosign_claim_url = request.data["claim_url"]
            HellosignCall.create_embedded_unclaimed_draft_with_template(self.user.company_id, self.requester_id, self.user.id)
          else
            self.errors.add(:signature_request_id, I18n.t('errors.template_missing'))
            return
          end
        elsif self.paperwork_packet.packet_type == PaperworkPacket.packet_types.key(PaperworkPacket.packet_types[:bulk]) && is_cosigned_document()
          self.paperwork_packet_type = PaperworkRequest.paperwork_packet_types[:bulk]
        elsif self.paperwork_packet.packet_type == PaperworkPacket.packet_types.key(PaperworkPacket.packet_types[:individual])
          self.paperwork_packet_type = PaperworkRequest.paperwork_packet_types[:individual]
        end
      end
    rescue HelloSign::Error::UnknownError => e
      self.errors.add(:signature_request_id, I18n.t('errors.timeout_error'))
    rescue HelloSign::Error::Conflict => e
      self.errors.add(:signature_request_id, I18n.t('errors.identical_request'))
    rescue Exception => e
      create_general_logging(self.user.try(:company), 'Create Hellosign request', { request: 'Create signature request with template', error: e.message })
      self.errors.add(:signature_request_id, I18n.t('errors.try_agian'))
    end
  end

  def hellosign_file_param
      if !Rails.env.development? && !Rails.env.test?
        return :file_urls
      else
        return :files
      end
  end

  def create_signature_draft
    begin
      signer_roles = get_signer_roles()
      request = HelloSign.create_embedded_unclaimed_draft(
          test_mode: self.user.company.get_hellosign_test_mode,
          client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
          type: 'request_signature',
          subject: self.document.title,
          message: self.document.description,
          requester_email_address: self.requester.email || self.requester.personal_email,
          hellosign_file_param => [self&.document&.attached_file&.url_for_hellosign],
          is_for_embedded_signing: 1,
          signers: signer_roles
      )
      self.hellosign_signature_request_id = request.data["signature_request_id"]
      self.hellosign_claim_url = request.data["claim_url"]
      HellosignCall.create_embedded_unclaimed_draft(self.user.company_id, self.requester_id, self.user.id)
    rescue HelloSign::Error::UnknownError => e
      self.errors.add(:signature_request_id, I18n.t('errors.timeout_error'))
    rescue HelloSign::Error::Conflict => e
      self.errors.add(:signature_request_id, I18n.t('errors.identical_request'))
    rescue Exception => e
      create_general_logging(self.user.try(:company), 'Create Hellosign request', { request: 'Create signature draft', error: e.message })
      self.errors.add(:signature_request_id, I18n.t('errors.try_agian'))
    end
  end
  
  def self.incomplete_paperworks(user_id)
    PaperworkRequest.where("user_id = ? AND (state = 'assigned' OR co_signer_id IS NOT NULL AND state != 'all_signed')", user_id).count
  end

  def self.overdue_paperwork_request_count(company)
    PaperworkRequest.non_draft_requests.exclude_offboarded_user_documents.get_pending_documents(company.id).where("paperwork_requests.due_date < ?", company.time.to_date).count
  end

  def self.open_paperwork_request_count(company)
    PaperworkRequest.non_draft_requests.exclude_offboarded_user_documents.get_pending_documents(company.id).where("paperwork_requests.due_date is NULL OR paperwork_requests.due_date >= ?", company.time.to_date).count
  end

  def is_cosigned_document
    return unless self.document.present? && self.document.paperwork_template.present?

    template = self.document.paperwork_template
    template.is_manager_representative.present? || template.representative_id.present?
  end

  def get_signer_roles
    signers = [
                { email_address: self.user.email || self.user.personal_email,
                  name: self.user.full_name,
                  role: 'employee',
                  order: 0
                }
               ]
    if self.co_signer_id
      role = 'representative'
      template = self.document.paperwork_template
      role = 'coworker' if template.present? && template.is_manager_representative
      signers << { email_address: self.co_signer.email || self.co_signer.personal_email,
                    name: self.co_signer.full_name,
                    role: role,
                    order: 1
                  }
    end
    signers
  end

  def self.template_without_all_signed current_company, user_id, previous_manager_id, state
    return current_company.users.find_by(id: user_id).paperwork_requests.where(paperwork_requests: { co_signer_id: previous_manager_id, co_signer_type: PaperworkRequest.co_signer_types[:manager] }).where.not(paperwork_requests: { state: state }) if current_company.present? && user_id.present? && previous_manager_id.present? && state.present?
  end

  def self.pending_hire_draft_paperwork_requests(user)
    user&.paperwork_requests&.draft_requests.select(:id, :document_id, :paperwork_packet_id)
  end
  
  def individual_fail_paperwork_request_email(is_user_associated, hellosign_call, error_message = '')
    self.decline
    impacted_user = hellosign_call.company.users.find_by_id(hellosign_call.user_ids.with_indifferent_access['user_id'])
    return if !impacted_user
    impacted_user_data = []
    impacted_user_data.push({ name: impacted_user.preferred_full_name, profile: 'https://' + hellosign_call.company.app_domain + '/#/documents/'+ impacted_user.id.to_s })
    UserMailer.document_assignment_failed_email(self, hellosign_call.company, error_message, is_user_associated, false, impacted_user_data).deliver_now!
  end

  def self.bulk_fail_paperwork_request_email(is_user_associated, hellosign_call, error_name = '', error_message = '')
    impacted_user_data = []
    
    hellosign_call.bulk_paperwork_requests.try(:each) do |request|
      next if !request['paperwork_request_id'].present? || !request['user_id'].present?
      
      paperwork_request = PaperworkRequest.find_by_id(request['paperwork_request_id'])
      impacted_user = hellosign_call.company.users.find_by_id(request['user_id'])
      next if !paperwork_request || !impacted_user

      paperwork_request.decline
      impacted_user_data.push({ name: impacted_user.preferred_full_name, profile: 'https://' + hellosign_call.company.app_domain + '/#/documents/'+ impacted_user.id.to_s })
      
      error_message = case error_name.downcase
                      when 'bad_request'
                        'An error occured while assigning document ' + paperwork_request&.document&.title + '. This might be due to invalid email address, or due to invalid signer role.'
                      when 'file_not_found'
                        'An error occured while assigning document <' + paperwork_request&.document&.title + '>. This occured due to accessing the resource that is no longer available.'
                      when 'other_exception'
                        'An error occured while assigning document <' + paperwork_request&.document&.title + '>.'
                      end
    end
    UserMailer.document_assignment_failed_email(nil, hellosign_call.company, error_message, is_user_associated, true, impacted_user_data, hellosign_call.job_requester).deliver_now! if impacted_user_data.present?
  end

  private

  def manage_post_sign_things
    begin
      user = self.user
      current_company = user.company
      self.sign_date = Date.today
      if self.save!
        send_document_completion_email(user, current_company) if current_company.document_completion_emails && ((self.co_signer_id.present? && self.all_signed?) || (self.co_signer_id.nil? && self.signed?))
        if self.signed?
          user.onboarding! if user.stage_onboarding?
          push_document_to_firebase() if self.co_signer_id
          manage_document_slack_notification_and_history(user, current_company)
          self.email_completely_send if self.co_signer_id && self.email_partially_sent?
        end
      end
    rescue Exception => e
      create_general_logging(current_company, 'Error during signing paperwork', { paperwork_request_id: self.id, error: e.message })
    end
  end
  
  def change_draft_state_to_preparing
    return if self.smart_assignment || self.state_assignment
    self.prepare
  end

  def send_document_email
    SendDocumentsAssignmentEmailJob.perform_async(self.id, 'paperwork_request') if ((paperwork_packet_id && co_signer_id && self.signed?) || !paperwork_packet_id)
  end

  def push_document_to_firebase
    firebase = Firebase::Client.new("#{ENV['FIREBASE_DATABASE_URL']}", ENV['FIREBASE_ADMIN_JSON'])
    firebase.set("paperwork_request_signed/" + self.hellosign_signature_request_id , true)
    firebase.set("paperwork_request_signed/" + self.co_signer_id.to_s, true)
  end

  def send_document_completion_email(user, company)
    UserMailer.send_document_completion_email(user, self.document, company).deliver_now!
  end

  def manage_document_slack_notification_and_history(user, company)
    SlackNotificationJob.perform_later(company.id, {
      username: user.full_name,
      text: I18n.t('slack_notifications.document.completed', name: self.document&.title)
    })
    create_document_history(company, user, self.document&.title, 'complete')
  end

  def should_send_to_third_party?
    state == (co_signer_id ? 'all_signed' : 'signed')
  end

  def update_hellosign_modal_opened_at
    self.update_column(:hellosign_modal_opened_at, Time.now)
  end
end
