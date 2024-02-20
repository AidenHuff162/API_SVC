class ReassignManagerActivitiesService
  attr_reader :company, :user_id, :previous_maanger_id

  def initialize(company, user_id, previous_manager_id)
    @company = company
    @user_id = user_id
    @user = @company.users.find_by(id: user_id)
    @current_manager = @user.manager
    @previous_manager = @company.users.find_by_id(previous_manager_id)
  end

  def perform()
  	return unless @company.present? && @user.present?
    send_pending_pto_email
    update_paperwork_template_representative
    reassign_tasks_to_manager
  end

  private

  def send_pending_pto_email
  	pending_pto_requests = PtoRequest.pending_pto_request(ApprovalChain.approval_types[:manager], @company, @user_id)
    if pending_pto_requests&.length > 0
      pending_pto_requests.map do |request|
        request.send_mail_to_approval_request_users
      end
    end
  end

  def update_paperwork_template_representative
  	return unless (@previous_manager&.id && @current_manager.present?)
 		pending_paperwork_requests = PaperworkRequest.template_without_all_signed(@company, @user_id, @previous_manager.id, ['all_signed', 'failed'])
  	if pending_paperwork_requests&.length > 0
      pending_paperwork_requests.map do |request|
      	request.update!(co_signer_id: @current_manager.id)
        unless request.draft?
          hellosign_signature_id = request.get_hellosign_signature_id(@previous_manager.get_email)
          HelloSign.update_signature_request(signature_request_id: request.hellosign_signature_request_id, signature_id: hellosign_signature_id, email_address: @current_manager.get_email, name: @current_manager.full_name) if hellosign_signature_id.present?
        	if request.state == "signed"
        		Interactions::Users::DocumentAssignedEmail.new({ id: @user_id, document_type: 'paperwork_request', document_id: request.id, co_signer_id: request.co_signer_id }).perform
          end
        end
      end
    end
  end

  def reassign_tasks_to_manager
    return unless (@previous_manager&.id && @current_manager.present?)
    @user.reassign_activities(@previous_manager.id, @current_manager.id, Task.task_types[:manager], nil)
  end
end
