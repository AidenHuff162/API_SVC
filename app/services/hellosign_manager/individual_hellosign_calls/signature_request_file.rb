module HellosignManager
  module IndividualHellosignCalls
    class SignatureRequestFile < HellosignService
      def call; signature_request_file end

      private

      def download_url
        filename = get_filename
        @paperwork_request.unsigned_document.download_url(filename)
      end

      def get_filename
        if @paperwork_request.paperwork_packet_id.blank? || @paperwork_request.individual?
          filename = @paperwork_request.document.title
        else
          filename = @paperwork_request.paperwork_packet.name
        end
        "#{filename} - #{@paperwork_request.user.full_name} (Not Signed).pdf"
      end

      def signature_request_file
        signature_request_id = @paperwork_request.hellosign_signature_request_id
        data = HelloSign.signature_request_files(signature_request_id: signature_request_id, file_type: 'pdf')
        tempfile = generate_temp_file(data)
        @paperwork_request.unsigned_document = File.open(tempfile.path)
        tempfile.close
        @paperwork_request.save!

        generate_firebase("paperwork_packet/#{@paperwork_request.hellosign_signature_request_id}", download_url)
      end
    end
  end
end
