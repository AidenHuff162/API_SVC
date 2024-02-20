module HellosignManager
  module IndividualHellosignCalls
    class BulkSendJobInformation < HellosignService
      def call; send_bulk_job_information end

      private

      def fetch_paginated_signature_requests(page)
        response = HTTParty.get("https://api.hellosign.com/v3/bulk_send_job/#{@hellosign_call.hellosign_bulk_request_job_id}?page=#{page}&page_size=100",
                                headers: { accept: 'application/json' },
                                basic_auth: { username: ENV['HELLOSIGN_API_KEY'], password: 'x' })
        JSON.parse(response.body)
      end

      def signature_requests
        page = 1
        signature_requests = []

        loop do
          response = fetch_paginated_signature_requests(page)
          return if response.blank? || response.key?('signature_requests').blank?

          signature_requests.push(response['signature_requests'])

          total_pages = response['list_info']['num_pages'] rescue 1
          page += 1
          break if page > total_pages
        end

        signature_requests.flatten
      end

      def send_bulk_document_email
        UserMailer.bulk_document_assigned_email(
          @hellosign_call.job_requester,
          @hellosign_call.created_at.in_time_zone(@company.time_zone).strftime('%I:%M%P'),
          @company
        ).deliver_now!
      end

      def update_hellosign_call_status(unassigned_paperwork_request)
        if unassigned_paperwork_request.empty?
          hellosign_call_completed
        else
          hellosign_call_partially_completed(:user_sapling, I18n.t('hellosign.bulk_send.description',unassigned_paperwork_request: unassigned_paperwork_request))
        end
      end

      def find_signer_id(signature_request)
        signer_email_address = signature_request['signatures'][0]['signer_email_address'] rescue nil
        @company.users.find_by("email = :signer_email OR personal_email =  :signer_email", signer_email: signer_email_address)&.id if signer_email_address
      end

      def bulk_paperwork_request_signer_index(bulk_paperwork_request, signature_request)
        signer_id = find_signer_id(signature_request)
        return if signer_id.blank?

        bulk_paperwork_request.map { |paperwork| paperwork['user_id'] }.find_index(signer_id)
      end

      def update_paperwork_request(paperwork_request, signature_request_id)
        paperwork_request.update(hellosign_signature_request_id: signature_request_id)
        paperwork_request.assign if @hellosign_call.assign_now
        generate_signature_request_files(paperwork_request)
      end

      def update_hellosign_bulk_response_status(bulk_response_status)
        @hellosign_call.update(hellosign_bulk_response_status: bulk_response_status)
      end


      def get_unassigned_paperwork_requests(signature_requests)
        unassigned_paperwork_request = []
        bulk_response_status= []

        signature_requests.each do |signature_request|
          bulk_paperwork_request = @hellosign_call.bulk_paperwork_requests

          signer_index = bulk_paperwork_request_signer_index(bulk_paperwork_request, signature_request)
          next if signer_index.blank?

          paperwork_request_id = bulk_paperwork_request[signer_index]['paperwork_request_id']
          paperwork_request = PaperworkRequest.find_by(id: paperwork_request_id)

          unassigned_paperwork_request.push(paperwork_request_id) if paperwork_request.blank?
          next if paperwork_request.blank?

          signature_request_id = signature_request['signature_request_id']
          next if signature_request_id.blank?

          update_paperwork_request(paperwork_request, signature_request_id)
          bulk_response_status.push(get_signature_request_hash(signature_request))
        end
        
        update_hellosign_bulk_response_status(bulk_response_status)
        unassigned_paperwork_request
      end

      def send_bulk_job_information
        unassigned_paperwork_request = get_unassigned_paperwork_requests(signature_requests)
        send_bulk_document_email
        update_hellosign_call_status(unassigned_paperwork_request)
      end

      def get_signature_request_hash(signature_request)
        {
          'signature_request_id' => signature_request['signature_request_id'],
          'bulk_send_job_id'     => signature_request['bulk_send_job_id'],
          'signature_id'         => signature_request['signatures'].first['signature_id'],
          'signer_email_address' => signature_request['signatures'].first['signer_email_address'],
          'template_id'          => signature_request['template_ids']&.first
        }
      end
    end
  end
end
