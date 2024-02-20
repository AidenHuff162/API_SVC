class ActiveAdmin::GetDocument
 
  def initialize(paperwork_request_entry_id)
    @paperwork_request=PaperworkRequest.find(paperwork_request_entry_id)   
    @document=''         
  end
  
  def perform
    if @paperwork_request.state == 'assigned' || (@paperwork_request.co_signer_id && @paperwork_request.state == 'signed' )
      get_unsigned_document
    else            
      get_signed_document
    end
   @document
  end

  private

  def get_unsigned_document
   @document=@paperwork_request.unsigned_document  
    unless @document.file.present?
      UnsignedDocumentJob.perform_now(paperwork_request_entry_id)
      @paperwork_request.reload
      @document=@paperwork_request.unsigned_document        
    end
  end


  def get_signed_document
    @document=@paperwork_request.signed_document  
    unless @document.file.present?
      ActiveAdmin::UploadSignedDocumentToHellosign.new.perform(@paperwork_request)
      @paperwork_request.reload
      @document=@paperwork_request.signed_document                   
    end
  end

end