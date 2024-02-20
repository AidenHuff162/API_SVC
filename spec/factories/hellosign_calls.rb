FactoryGirl.define do
  factory :hellosign_call do
    state :in_progress
    priority :high
    call_type :individual
  end

  factory :bulk_send_job_information_hellosign_call, parent: :hellosign_call do
    api_end_point :bulk_send_job_information
    hellosign_bulk_request_job_id 1
  end

  factory :embedded_combined_hellosign_call, parent: :hellosign_call do
    api_end_point :create_embedded_signature_request_with_template_combined
    hellosign_bulk_request_job_id 1
  end

  factory :embedded_hellosign_call, parent: :hellosign_call do
    api_end_point :create_embedded_signature_request_with_template
    hellosign_bulk_request_job_id 1
  end

  factory :firebase_signed_document, parent: :hellosign_call do
    api_end_point :firebase_signed_document
    hellosign_bulk_request_job_id 1
  end

  factory :signature_request_files, parent: :hellosign_call do
    api_end_point :signature_request_files
    hellosign_bulk_request_job_id 1
  end

  factory :update_signature_request_cosigner, parent: :hellosign_call do
    api_end_point :update_signature_request_cosigner
    hellosign_bulk_request_job_id 1
  end

  factory :update_template_files, parent: :hellosign_call do
    api_end_point :update_template_files
    hellosign_bulk_request_job_id 1
  end
end
