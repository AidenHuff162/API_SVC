class UpdateSignatureRequestJob < ApplicationJob
  queue_as :generate_big_reports

  def perform(user_id, old_email, new_email)
  	paper_work_requests = PaperworkRequest.where("state != 'draft' AND (user_id = ? AND state != 'signed')
                                                  OR (co_signer_id IS NOT NULL AND co_signer_id = ? AND 
                                                  state != 'all_signed')", user_id, user_id)
  	paper_work_requests.each do |paperwork_request|
  		paperwork_request.update_hellosign_signature_email(old_email, new_email)
  	end
  end
end
