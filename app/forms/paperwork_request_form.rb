class PaperworkRequestForm < BaseForm
  presents :paperwork_request
  attribute :id, Integer
  attribute :user_id, Integer
  attribute :document_id, Integer
  attribute :hellosign_signature_id, String
  attribute :hellosign_signature_request_id, String
  attribute :state, String
  attribute :requester_id, Integer
  attribute :signed_document, String
  attribute :unsigned_document, String
  attribute :paperwork_packet_id, Integer
  attribute :template_ids, Array[Integer]
  attribute :co_signer_id, Integer
  attribute :co_signer_type, Integer
  attribute :smart_assignment, Boolean
  attribute :due_date, Date
  attribute :state_assignment, Boolean
  attribute :document_token, String
end
