class ActiveAdmin::UploadSignedDocumentToHellosign
  def perform(paperwork)
    response = HelloSign.signature_request_files :signature_request_id => paperwork.hellosign_signature_request_id
    tempfile = Tempfile.new(['doc', '.pdf'])
    tempfile.binmode
    tempfile.write response
    tempfile.rewind
    tempfile.close
    paperwork.signed_document = File.open tempfile.path
    paperwork.save

    firebase = Firebase::Client.new("#{ENV['FIREBASE_DATABASE_URL']}", ENV['FIREBASE_ADMIN_JSON'])
    response = firebase.set("paperwork_request/" + paperwork.hellosign_signature_request_id , paperwork.get_signed_document_url)
    paperwork.send_document_to_bamboo
  end
end
