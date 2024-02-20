class BulkAssignPaperworkTemplateService
  attr_reader :company, :user, :attributes, :paperwork_packet

  def initialize(company, user, attributes, paperwork_packet)
    @company = company
    @user = user
    @attributes = attributes
    @paperwork_packet = paperwork_packet
  end

  def perform(paperwork_template_ids)
    return unless paperwork_template_ids.present?
    
    paperwork_templates = company.paperwork_templates.where(id: paperwork_template_ids)
    return unless paperwork_templates.present?
    
    allocate(paperwork_templates)
  end

  private

  def allocate(paperwork_templates)
    if paperwork_packet.individual?
      allocate_individual_packet(paperwork_templates)
    else
      allocate_bulk_packet(paperwork_templates)
    end
  end

  def allocate_individual_packet(paperwork_templates)
    paperwork_templates.each do |paperwork_template|
      HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(paperwork_template.id, attributes[:users], user.id, company, nil, paperwork_templates.pluck(:id), paperwork_packet)
    end
  end

  def allocate_bulk_packet(paperwork_templates)
    cosigned_paperwork_templates = paperwork_templates.where('is_manager_representative = ? OR representative_id IS NOT NULL', true)
    allocate_individual_packet(cosigned_paperwork_templates) if cosigned_paperwork_templates.present?

    non_cosigned_paperwork_templates = paperwork_templates.where('is_manager_representative = ? AND representative_id IS NULL', false)
    create_single_sign_on_bulk_paperwork_request(non_cosigned_paperwork_templates) if non_cosigned_paperwork_templates.present?
  end

  def create_single_sign_on_bulk_paperwork_request(paperwork_templates)
    iteration = 1
    allowed_users = 0
    paperwork_requests = []

    allowed_users = (company.get_hellosign_test_mode == Company::HELLOSIGN_TEST_MODE_ENABLED) ? 250 : 5
    document_id = company.documents.find_by(id: paperwork_templates.order(:id).take.document_id).try(:id)
    return unless document_id.present?

    params = { document_id: document_id, paperwork_packet_id: paperwork_packet.id, template_ids: paperwork_templates.pluck(:id), requester_id: user.id, paperwork_packet_type: paperwork_packet.packet_type }
    
    attributes[:users].try(:each) do |user|
      if company.users.find_by(id: user['id']).present?

        if user['document_token'].present?
          document_token = user['document_token']
        else
          document_token = SecureRandom.uuid + "-" + DateTime.now.to_s
        end
        
        paperwork_request = PaperworkRequest.new(params.merge({user_id: user['id'], document_token: document_token}))
        paperwork_request.save!(validate: false)

        paperwork_requests.push({
          :paperwork_request_id => paperwork_request.id,
          :user_id => user["id"]
        })

        if iteration % allowed_users == 0 || iteration == attributes[:users].size
          HellosignCall.create_embedded_bulk_send_with_template_of_paperwork_packet(paperwork_requests, @company.id, paperwork_templates.ids, @user.id)
          paperwork_requests = []
        end
      end
      iteration += 1
    end
  end
end
