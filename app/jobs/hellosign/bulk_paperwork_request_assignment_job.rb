class Hellosign::BulkPaperworkRequestAssignmentJob
  include Sidekiq::Worker
  sidekiq_options :queue => :bulk_paperwork_request_assignment, :retry => 0, :backtrace => true

  def perform(paperwork_template_id, users, current_user_id, current_company_id, due_date)
    current_company = Company.find_by_id(current_company_id)
    HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(paperwork_template_id,
      users,
      current_user_id,
      current_company,
      due_date
    )
  end
end
