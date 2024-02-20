class UnsignedDocumentJob < ApplicationJob
  queue_as :unsigned_document

  def perform(id, retries = 1)
    return if Rails.env.test?
    begin
      paperwork_request = PaperworkRequest.find_by(id: id)
      if paperwork_request
        data = HelloSign.signature_request_files signature_request_id: paperwork_request.hellosign_signature_request_id, file_type: 'pdf'
        tempfile = Tempfile.new(['doc', '.pdf'])
        tempfile.binmode
        tempfile.write data
        tempfile.rewind
        tempfile.close

        paperwork_request.unsigned_document = File.open tempfile.path
        paperwork_request.save!
        
        download_url = paperwork_request.get_unsigned_document_url
        firebase = Firebase::Client.new("#{ENV['FIREBASE_DATABASE_URL']}", ENV['FIREBASE_ADMIN_JSON'])
        response = firebase.set("paperwork_packet/" + paperwork_request.hellosign_signature_request_id , download_url)
      end
    rescue Exception => e
      puts e
      puts '-----------------------------------------------------'
      puts '----------UnsignedDocumentJob Exception -------------'
      puts '-----------------------------------------------------'

      LoggingService::GeneralLogging.new.create(paperwork_requests&.user&.company, 'Get Hello-sign request #UnsignedDocumentJob', 
        { error: e.message, retry_count: retries, hellosign_signature_request_id: paperwork_request.try(:hellosign_signature_request_id) })

      if retries < 5
        wait_time = (30 * retries)
        retries += 1
        UnsignedDocumentJob.set(wait: wait_time.seconds).perform_later(id, retries)
      end
    end
  end
end
