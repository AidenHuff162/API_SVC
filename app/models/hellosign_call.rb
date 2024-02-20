class HellosignCall < ApplicationRecord
  belongs_to :company
  belongs_to :job_requester, class_name: 'User'
  
  enum state: { in_progress: 0, completed: 1, failed: 2, partially_completed: 3 }
  enum call_type: { individual: 0, bulk: 1 }
  enum priority: { high: 0, medium: 1, low: 2 }
  enum error_category: { user: 0, sapling: 1, hellosign: 2, user_sapling: 3 }

  scope :get_hellosign_bulk_call, -> { where('priority = ? AND state = ? AND call_type = ?', HellosignCall.priorities[:low], HellosignCall.states[:in_progress], HellosignCall.call_types[:bulk]).order(:created_at)}
  scope :get_enqueued_calls_count, -> (paperwork_request_id, api_end_point) { where('paperwork_request_id = ? AND api_end_point = ? AND state = ?', paperwork_request_id, api_end_point, HellosignCall.states[:in_progress]).count }
  
  def self.create_embedded_signature_request_with_template(user_ids, paperwork_request_id, assign_now, company_id, job_requester_id, smart_assignment = false)
    if smart_assignment
      self.create!(
        state: HellosignCall.states[:in_progress],
        call_type: HellosignCall.call_types[:individual],
        priority: HellosignCall.priorities[:high],
        api_end_point: 'create_embedded_signature_request_with_template',
        user_ids: user_ids,
        paperwork_request_id: paperwork_request_id,
        assign_now: assign_now,
        job_requester_id: job_requester_id,
        company_id: company_id
      )
    else
      self.create!(
        state: HellosignCall.states[:in_progress],
        call_type: HellosignCall.call_types[:individual],
        priority: HellosignCall.priorities[:medium],
        api_end_point: 'create_embedded_signature_request_with_template',
        user_ids: user_ids,
        paperwork_request_id: paperwork_request_id,
        assign_now: assign_now,
        job_requester_id: job_requester_id,
        company_id: company_id
      )
    end
  end

  def self.create_signature_request_files(paperwork_request_id, company_id, job_requester_id)
    self.create!(
      state: HellosignCall.states[:in_progress],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:high],
      api_end_point: 'signature_request_files',
      paperwork_request_id: paperwork_request_id,
      job_requester_id: job_requester_id,
      company_id: company_id
    )
  end

  def self.create_bulk_send_job_information(bulk_job_id, company_id, bulk_paperwork_requests, assign_now, job_requester_id)
    self.create!(
      state: HellosignCall.states[:in_progress],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:high],
      api_end_point: 'bulk_send_job_information',
      hellosign_bulk_request_job_id: bulk_job_id,
      bulk_paperwork_requests: bulk_paperwork_requests,
      assign_now: assign_now,
      job_requester_id: job_requester_id,
      company_id: company_id
    )
  end

  def self.create_embedded_bulk_send_with_template_of_individual_document(paperwork_template_id, users, requester_id, company, paperwork_request_due_date = nil, paperwork_template_ids = [], paperwork_packet = nil, user_tokens = nil)
    return unless company.present? || paperwork_template_id.present?
    
    paperwork_template = company.paperwork_templates.find_by_id(paperwork_template_id)
    return unless paperwork_template

    iteration = 1
    allowed_users = 0
    user_ids = {}
    paperwork_requests = []

    allowed_users = (company.get_hellosign_test_mode == Company::HELLOSIGN_TEST_MODE_ENABLED) ? 250 : 5
    document = company.documents.find_by(id: paperwork_template.document_id)
    return unless document

    users.each do |user|
      if user['document_token'].present?
        document_token = user['document_token']
      elsif user_tokens.present?
        document_token = user_tokens[user['id'].to_s]
      else
        document_token = SecureRandom.uuid + "-" + DateTime.now.to_s
      end

      attributes = { document_id: document.id, user_id: user['id'], requester_id: requester_id, document_token: document_token }

      if paperwork_template.is_cosigned?
        co_signer_id = (paperwork_template.is_manager_representative.blank? ? paperwork_template.representative_id : (user.is_a?(Hash).blank? ? user.manager_id : user['manager']['id'])) rescue nil
        next if co_signer_id.blank?
        
        co_signer_type = nil
        if paperwork_template.is_manager_representative
          co_signer_type = 0
        elsif !paperwork_template.is_manager_representative && paperwork_template.representative_id.present?
          co_signer_type = 1
        end

        attributes.merge!({ co_signer_id: co_signer_id, co_signer_type: co_signer_type })
      end

      if paperwork_request_due_date.present?
        attributes.merge!({ due_date: paperwork_request_due_date })
      end

      if paperwork_packet.present?
        attributes.merge!({ template_ids: paperwork_template_ids, paperwork_packet_id: paperwork_packet.id, paperwork_packet_type: paperwork_packet.packet_type })
      end
      
      paperwork_request = PaperworkRequest.new(attributes)
      paperwork_request.save!(validate: false)

      user_ids['user_id'] = user['id']
      case paperwork_template.is_cosigned?
      when true
        user_ids['co_signer_id'] = co_signer_id
        self.create_embedded_signature_request_with_template(user_ids, paperwork_request.id, true, company.id, requester_id)
      when false
        paperwork_requests.push({
          paperwork_request_id: paperwork_request.id,
          user_id: user['id']
        })
        if iteration % allowed_users == 0 || iteration == users.size
          self.create_embedded_bulk_send_with_template_of_paperwork_packet(paperwork_requests, company.id, [paperwork_template.id], requester_id)
          user_ids = {}
          paperwork_requests = []
        end
      end      
      iteration += 1
    end
  end

  def self.create_embedded_bulk_send_with_template_of_paperwork_packet(bulk_paperwork_requests, company_id, paperwork_template_ids, job_requester_id)
    self.create!(
      state: HellosignCall.states[:in_progress],
      call_type: HellosignCall.call_types[:bulk],
      priority: HellosignCall.priorities[:low],
      api_end_point: 'embedded_bulk_send_with_template',
      assign_now: true,
      paperwork_template_ids: paperwork_template_ids,
      bulk_paperwork_requests: bulk_paperwork_requests,
      job_requester_id: job_requester_id,
      company_id: company_id
    )
  end

  def self.update_template_files(paperwork_template_id, company_id, job_requester_id)
    self.create!(
      state: HellosignCall.states[:in_progress],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:medium],
      api_end_point: 'update_template_files',
      paperwork_template_ids: [paperwork_template_id],
      job_requester_id: job_requester_id,
      company_id: company_id
    )
  end

  def self.upload_signed_document_to_firebase(paperwork_request_id, company_id, job_requester_id)
    self.create!(
      state: HellosignCall.states[:in_progress],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:medium],
      api_end_point: 'firebase_signed_document',
      paperwork_request_id: paperwork_request_id,
      job_requester_id: job_requester_id,
      company_id: company_id
    )
  end

  def self.create_embedded_signature_request_with_template_combined(paperwork_request_id, paperwork_template_ids, job_requester_id, company_id, user_id)
    self.create!(
      state: HellosignCall.states[:in_progress],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:high],
      api_end_point: 'create_embedded_signature_request_with_template_combined',
      paperwork_request_id: paperwork_request_id,
      paperwork_template_ids: paperwork_template_ids,
      assign_now: true,
      job_requester_id: job_requester_id,
      company_id: company_id,
      user_ids: user_id
    )
  end

  def self.create_embedded_unclaimed_draft_with_template(company_id, job_requester_id, user_id)
    self.create!(
      state: HellosignCall.states[:completed],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:high],
      api_end_point: 'create_embedded_unclaimed_draft_with_template',
      job_requester_id: job_requester_id,
      company_id: company_id,
      user_ids: user_id
    )
  end

  def self.create_embedded_unclaimed_draft(company_id, job_requester_id, user_id)
    self.create!(
      state: HellosignCall.states[:completed],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:high],
      api_end_point: 'create_embedded_unclaimed_draft',
      job_requester_id: job_requester_id,
      company_id: company_id,
      user_ids: user_id
    )
  end

  def self.update_signature_request_cosigner(paperwork_request_id, company_id, job_requester_id)
    self.create!(
      state: HellosignCall.states[:in_progress],
      call_type: HellosignCall.call_types[:individual],
      priority: HellosignCall.priorities[:medium],
      api_end_point: 'update_signature_request_cosigner',
      paperwork_request_id: paperwork_request_id,
      company_id: company_id,
      job_requester_id: job_requester_id
    )
  end
end
